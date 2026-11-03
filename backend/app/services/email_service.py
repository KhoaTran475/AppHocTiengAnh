import logging
import smtplib
from email.header import Header
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr
from app.core.config import settings

logger = logging.getLogger(__name__)


def generate_otp_html(otp_code: str, otp_type: str = "register") -> str:
    """Tạo giao diện email HTML hiện đại, chuyên nghiệp cho ứng dụng IELTS Vision."""
    action_text = "Đăng ký tài khoản mới"
    if otp_type == "login":
        action_text = "Đăng nhập nhanh vào tài khoản"
    elif otp_type == "reset_password":
        action_text = "Đặt lại mật khẩu tài khoản"

    return f"""<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mã Xác Thực IELTS Vision</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #0F172A;
      color: #F8FAFC;
      margin: 0;
      padding: 24px;
    }}
    .container {{
      max-width: 540px;
      margin: 0 auto;
      background: #1E293B;
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid #334155;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
    }}
    .header {{
      background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%);
      padding: 32px 24px;
      text-align: center;
    }}
    .header h1 {{
      margin: 0;
      font-size: 26px;
      font-weight: 800;
      letter-spacing: 0.5px;
      color: #FFFFFF;
    }}
    .header p {{
      margin: 8px 0 0;
      font-size: 14px;
      color: #E0E7FF;
      font-weight: 500;
    }}
    .content {{
      padding: 32px 28px;
    }}
    .greeting {{
      font-size: 16px;
      color: #E2E8F0;
      margin-bottom: 16px;
    }}
    .desc {{
      font-size: 14px;
      color: #94A3B8;
      line-height: 1.6;
      margin-bottom: 28px;
    }}
    .otp-box {{
      background: #0F172A;
      border: 2px dashed #6366F1;
      border-radius: 12px;
      padding: 20px;
      text-align: center;
      margin-bottom: 28px;
    }}
    .otp-code {{
      font-size: 38px;
      font-weight: 800;
      letter-spacing: 8px;
      color: #38BDF8;
      font-family: 'Courier New', Courier, monospace;
      display: inline-block;
      margin: 4px 0;
    }}
    .otp-exp {{
      font-size: 12px;
      color: #F59E0B;
      font-weight: 600;
      margin-top: 8px;
    }}
    .warning {{
      background: rgba(239, 68, 68, 0.1);
      border-left: 4px solid #EF4444;
      padding: 12px 16px;
      border-radius: 6px;
      font-size: 13px;
      color: #FCA5A5;
      line-height: 1.5;
      margin-bottom: 24px;
    }}
    .footer {{
      background: #0F172A;
      padding: 18px 24px;
      text-align: center;
      font-size: 12px;
      color: #64748B;
      border-top: 1px solid #334155;
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>IELTS VISION</h1>
      <p>Nền tảng Luyện thi IELTS 4 Kỹ năng & AI Trực quan</p>
    </div>
    <div class="content">
      <div class="greeting">Xin chào bạn,</div>
      <div class="desc">
        Bạn đang thực hiện yêu cầu <strong>{action_text}</strong> trên ứng dụng IELTS Vision. 
        Vui lòng sử dụng mã xác thực (OTP) bên dưới để hoàn tất:
      </div>
      <div class="otp-box">
        <div class="otp-code">{otp_code}</div>
        <div class="otp-exp">⏳ Mã có hiệu lực trong vòng {settings.OTP_EXPIRE_MINUTES} phút</div>
      </div>
      <div class="warning">
        🔒 <strong>Lưu ý bảo mật:</strong> Tuyệt đối không cung cấp mã OTP này cho bất kỳ ai, kể cả nhân viên hỗ trợ IELTS Vision.
      </div>
      <div class="desc" style="margin-bottom: 0;">
        Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email hoặc đổi mật khẩu tài khoản ngay lập tức.
      </div>
    </div>
    <div class="footer">
      © 2026 IELTS Vision Team. All rights reserved.<br>
      Email tự động, vui lòng không trả lời thư này.
    </div>
  </div>
</body>
</html>
"""


def send_email_sync(to_email: str, subject: str, html_content: str, text_content: str = "") -> bool:
    """Hàm đồng bộ (synchronous) gửi email qua Gmail SMTP.
    
    LƯU Ý KỸ THUẬT QUAN TRỌNG:
    Bắt buộc phải là hàm chuẩn `def` (không phải `async def`) để khi được truyền vào
    FastAPI BackgroundTasks, framework sẽ tự động đưa sang ThreadPool riêng (anyio.to_thread),
    tuyệt đối không phong tỏa Event Loop chính của Backend.
    """
    clean_email = to_email.strip().lower()
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = Header(subject, "utf-8")
    msg["From"] = formataddr((str(Header(settings.SMTP_FROM_NAME, "utf-8")), settings.SMTP_USER))
    msg["To"] = clean_email

    if text_content:
        msg.attach(MIMEText(text_content, "plain", "utf-8"))
    if html_content:
        msg.attach(MIMEText(html_content, "html", "utf-8"))

    try:
        if settings.SMTP_PORT == 465:
            with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.sendmail(settings.SMTP_USER, [clean_email], msg.as_string())
        else:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
                server.starttls()
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.sendmail(settings.SMTP_USER, [clean_email], msg.as_string())

        logger.info(f"Đã gửi email thành công tới: {clean_email}")
        return True
    except Exception as e:
        logger.error(f"Thất bại khi gửi email tới {clean_email}: {e}")
        return False


def send_otp_email_sync(to_email: str, otp_code: str, otp_type: str = "register") -> bool:
    """Gửi email chứa mã OTP xác thực đồng bộ (Non-blocking khi bọc trong BackgroundTasks)."""
    subject_map = {
        "register": "Mã xác thực Đăng ký tài khoản IELTS Vision",
        "login": "Mã xác thực Đăng nhập IELTS Vision",
        "reset_password": "Mã xác thực Đặt lại mật khẩu IELTS Vision",
    }
    subject = subject_map.get(otp_type, "Mã xác thực IELTS Vision")
    html_content = generate_otp_html(otp_code=otp_code, otp_type=otp_type)
    text_fallback = f"Mã xác thực IELTS Vision của bạn là: {otp_code}. Hiệu lực trong {settings.OTP_EXPIRE_MINUTES} phút."
    
    return send_email_sync(
        to_email=to_email,
        subject=subject,
        html_content=html_content,
        text_content=text_fallback,
    )

