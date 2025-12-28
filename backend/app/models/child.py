from sqlalchemy import Column, Integer, String, JSON, DateTime, CheckConstraint
from sqlalchemy.sql import func
from ..db import Base


class Child(Base):
    __tablename__ = "children"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    age = Column(Integer, nullable=False)
    gender = Column(String, nullable=False)  # "male" или "female"
    interests = Column(JSON, nullable=True)
    fears = Column(JSON, nullable=True)
    personality = Column(String, nullable=True)
    moral = Column(String, nullable=True)
    profile_json = Column(JSON, nullable=True)
    user_id = Column(String, nullable=True)  # UUID пользователя
    face_url = Column(String, nullable=True)  # URL фотографии ребёнка
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    __table_args__ = (
        CheckConstraint("gender IN ('male', 'female')", name="check_gender"),
    )

