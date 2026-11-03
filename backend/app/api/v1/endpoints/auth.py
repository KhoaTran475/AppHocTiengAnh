import logging
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import get_current_user
from app.core.security import create_access_token
from app.db.session import get_db
from app.models.user import User
from app.models.email_otp import EmailOTP
from app.schemas.user import (
    UserCreate,
    UserLogin,
    AdminLoginRequest,
    UserResponse,
    Token,
    SendOTPRequest,
    RegisterOTPVerifyRequest,
    LoginOTPRequest,
    OTPResponse,
)
from app.services.user_service import (
    authenticate_user,
    create_user,
    get_user_by_username,
    get_user_by_email,
)
from app.services.email_service import send_otp_email_sync

logger = logging.getLogger(__name__)

router = APIRouter()


# ─────────────────────────────────────────────────────────────
# 1. ADMIN AUTHENTICATION (Cổng dành riêng cho Web Admin)
# ─────────────────────────────────────────────────────────────

@router.post("/admin/login", response_model=Token, summary="Đăng nhập Web Quản trị (Admin Only)")
def admin_login(login_data: AdminLoginRequest, db: Session = Depends(get_db)):
    """
    Endpoint xác thực dành riêng cho Cổng Quản trị Web (/admin).
    
    Quy tắc bảo mật bắt buộc:
    - Chỉ chấp nhận tài khoản có role == 'admin'.
    - Nếu tài khoản hợp lệ nhưng role là 'learner', từ chối với HTTP 403 Forbidden.
    """
    user = authenticate_user(db, login_data.username, login_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
        )

    if user.role != "admin":
        logger.warning(f"Từ chối quyền truy cập Web Admin của học viên '{user.username}'.")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản này là Học viên, không có quyền truy cập trang Quản trị.",
        )

    access_token = create_access_token(subject=user.username, role=user.role)
    logger.info(f"Admin '{user.username}' đã đăng nhập thành công vào Web Admin.")
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(user),
    )


# ─────────────────────────────────────────────────────────────
# 2. EMAIL OTP FLOW (Dành cho Học viên trên Flutter)
# ─────────────────────────────────────────────────────────────

@router.post("/send-otp", response_model=OTPResponse, summary="Gửi mã OTP qua Email (Non-blocking)")
def send_otp(
    req: SendOTPRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    Tạo và gửi mã OTP 6 chữ số qua Gmail SMTP trong BackgroundTasks (Non-blocking).
    
    Ràng buộc kỹ thuật:
    1. Chuẩn hóa email: email.strip().lower()
    2. Chống gửi lãng phí (type='register'): Nếu email đã tồn tại và đã kích hoạt (is_email_verified=True),
       trả về 400 Bad Request ngay, KHÔNG gửi email.
    3. Kiểm tra tài khoản (type='login'): Bắt buộc tài khoản phải tồn tại và có role='learner'.
    4. Rate limit: Tối thiểu 60 giây giữa 2 lần yêu cầu gửi mã của cùng một email.
    """
    clean_email = req.email.strip().lower()

    # 1. Kiểm tra chống gửi lãng phí cho loại Đăng ký
    if req.type == "register":
        existing_verified = db.query(User).filter(
            User.email == clean_email,
            User.is_email_verified == True,
        ).first()
        if existing_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng email khác.",
            )

    # 2. Kiểm tra tài khoản cho loại Đăng nhập
    elif req.type == "login":
        learner_user = db.query(User).filter(User.email == clean_email).first()
        if not learner_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy tài khoản học viên với email này. Vui lòng đăng ký mới.",
            )
        if learner_user.role != "learner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Phương thức đăng nhập OTP chỉ dành cho tài khoản Học viên trên thiết bị di động.",
            )

    # 3. Rate Limit: Kiểm tra khoảng cách 60 giây chống spam
    last_otp = db.query(EmailOTP).filter(
        EmailOTP.email == clean_email,
    ).order_by(EmailOTP.id.desc()).first()

    if last_otp:
        time_diff = (datetime.utcnow() - last_otp.created_at).total_seconds()
        if time_diff < 60:
            remaining_seconds = int(60 - time_diff)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Vui lòng chờ {remaining_seconds} giây trước khi yêu cầu gửi lại mã OTP mới.",
            )

    # 4. Sinh mã OTP 6 chữ số ngẫu nhiên an toàn bảo mật
    otp_code = f"{secrets.randbelow(900000) + 100000}"
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    # 5. Lưu vào Database
    new_otp = EmailOTP(
        email=clean_email,
        otp_code=otp_code,
        otp_type=req.type,
        attempts=0,
        expires_at=expires_at,
        is_used=False,
    )
    db.add(new_otp)
    db.commit()

    # 6. Điều phối gửi email bất đồng bộ qua ThreadPool bằng send_otp_email_sync (Non-blocking I/O)
    background_tasks.add_task(send_otp_email_sync, clean_email, otp_code, req.type)

    logger.info(f"Đã tạo OTP ({req.type}) cho email: {clean_email}")
    return OTPResponse(
        message="Mã xác thực OTP đã được gửi đến email của bạn. Vui lòng kiểm tra hộp thư.",
        expires_in_seconds=settings.OTP_EXPIRE_MINUTES * 60,
    )


@router.post("/register-verify-otp", response_model=Token, status_code=status.HTTP_201_CREATED, summary="Xác thực OTP & Hoàn tất Đăng ký")
def register_verify_otp(
    req: RegisterOTPVerifyRequest,
    db: Session = Depends(get_db),
):
    """
    Xác thực mã OTP và khởi tạo tài khoản Học viên mới.
    
    Cơ chế Anti-Brute-Force:
    - Nếu nhập sai mã OTP: Tăng attempts += 1.
    - Nếu attempts >= 5: Đánh dấu is_used = True, từ chối vĩnh viễn mã này và bắt buộc gửi mã mới.
    """
    clean_email = req.email.strip().lower()
    clean_username = req.username.strip().lower()

    # 1. Kiểm tra username đã tồn tại chưa
    if get_user_by_username(db, clean_username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.",
        )

    # 2. Kiểm tra email đã có người dùng kích hoạt chưa
    if db.query(User).filter(User.email == clean_email, User.is_email_verified == True).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email này đã được đăng ký và kích hoạt.",
        )

    # 3. Tìm mã OTP hợp lệ gần nhất
    otp_record = db.query(EmailOTP).filter(
        EmailOTP.email == clean_email,
        EmailOTP.otp_type == "register",
        EmailOTP.is_used == False,
    ).order_by(EmailOTP.id.desc()).first()

    if not otp_record or otp_record.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã OTP không tồn tại hoặc đã hết hạn. Vui lòng bấm gửi lại mã mới.",
        )

    # 4. Anti-Brute-Force Protection
    if otp_record.otp_code != req.otp.strip():
        otp_record.attempts += 1
        if otp_record.attempts >= 5:
            otp_record.is_used = True
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bạn đã nhập sai mã OTP quá 5 lần. Mã này đã bị vô hiệu hóa, vui lòng gửi lại mã mới.",
            )
        db.commit()
        remaining = 5 - otp_record.attempts
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mã OTP không chính xác. Bạn còn {remaining} lần thử.",
        )

    # 5. OTP hợp lệ -> Vô hiệu hóa OTP & Tạo User mới
    otp_record.is_used = True
    db.commit()

    user_create = UserCreate(
        username=clean_username,
        password=req.password,
        role="learner",
        email=clean_email,
    )
    new_user = create_user(db, user_create, sync_supabase=True, is_email_verified=True)

    access_token = create_access_token(subject=new_user.username, role=new_user.role)
    logger.info(f"Học viên '{new_user.username}' đã đăng ký tài khoản thành công qua Email OTP.")
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(new_user),
    )


@router.post("/login-otp", response_model=Token, summary="Đăng nhập không cần mật khẩu qua Email OTP")
def login_with_otp(
    req: LoginOTPRequest,
    db: Session = Depends(get_db),
):
    """
    Đăng nhập an toàn cho Học viên (Mobile Learner) bằng Email và OTP (Passwordless).
    
    Cơ chế Anti-Brute-Force:
    - Nếu nhập sai mã OTP: Tăng attempts += 1.
    - Nếu attempts >= 5: Vô hiệu hóa mã và yêu cầu gửi lại mã mới.
    """
    clean_email = req.email.strip().lower()

    # 1. Tìm tài khoản học viên
    user = db.query(User).filter(User.email == clean_email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy tài khoản với email này.",
        )

    if user.role != "learner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Phương thức đăng nhập này chỉ dành cho Học viên trên thiết bị di động.",
        )

    # 2. Tìm mã OTP đăng nhập
    otp_record = db.query(EmailOTP).filter(
        EmailOTP.email == clean_email,
        EmailOTP.otp_type == "login",
        EmailOTP.is_used == False,
    ).order_by(EmailOTP.id.desc()).first()

    if not otp_record or otp_record.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã OTP không tồn tại hoặc đã hết hạn. Vui lòng bấm gửi lại mã mới.",
        )

    # 3. Anti-Brute-Force Protection
    if otp_record.otp_code != req.otp.strip():
        otp_record.attempts += 1
        if otp_record.attempts >= 5:
            otp_record.is_used = True
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bạn đã nhập sai mã OTP quá 5 lần. Mã này đã bị vô hiệu hóa, vui lòng gửi lại mã mới.",
            )
        db.commit()
        remaining = 5 - otp_record.attempts
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mã OTP không chính xác. Bạn còn {remaining} lần thử.",
        )

    # 4. OTP hợp lệ -> Cấp token
    otp_record.is_used = True
    # Đảm bảo cờ is_email_verified được bật nếu chưa bật
    if not user.is_email_verified:
        user.is_email_verified = True
    db.commit()

    access_token = create_access_token(subject=user.username, role=user.role)
    logger.info(f"Học viên '{user.username}' đã đăng nhập thành công qua Email OTP.")
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(user),
    )


# ─────────────────────────────────────────────────────────────
# 3. TRADITIONAL AUTH (Username/Password) & PROFILE
# ─────────────────────────────────────────────────────────────

@router.post("/login", response_model=Token, summary="Đăng nhập tài khoản bằng mật khẩu")
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """Đăng nhập bằng username/email và password. Trả về Bearer JWT Access Token."""
    user = authenticate_user(db, login_data.username, login_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
        )
    
    access_token = create_access_token(subject=user.username, role=user.role)
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(user),
    )


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED, summary="Đăng ký tài khoản học viên truyền thống")
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """Đăng ký tài khoản mới (mặc định role 'learner')."""
    try:
        new_user = create_user(db, user_in, sync_supabase=True, is_email_verified=False)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    
    access_token = create_access_token(subject=new_user.username, role=new_user.role)
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(new_user),
    )


@router.get("/me", response_model=UserResponse, summary="Lấy thông tin tài khoản hiện tại")
def get_current_user_profile(current_user: User = Depends(get_current_user)):
    """Trả về thông tin hồ sơ của người dùng đang đăng nhập qua Bearer Token."""
    return UserResponse.model_validate(current_user)
