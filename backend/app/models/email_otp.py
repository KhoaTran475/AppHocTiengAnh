from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from app.db.session import Base


class EmailOTP(Base):
    __tablename__ = "email_otps"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), index=True, nullable=False)
    otp_code = Column(String(10), nullable=False)
    otp_type = Column(String(20), default="register", nullable=False)  # 'register', 'login', 'reset_password'
    attempts = Column(Integer, default=0, nullable=False)  # Cơ chế chống brute-force (tối đa 5 lần)
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    def __repr__(self):
        return f"<EmailOTP id={self.id} email={self.email} type={self.otp_type} attempts={self.attempts} used={self.is_used}>"

