from fastapi import APIRouter
from app.api.v1.endpoints import auth, users, admin, vision, vocabulary, notebook, skills, face_auth

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(face_auth.router, prefix="/auth/face", tags=["FaceID Authentication (Biometrics)"])
api_router.include_router(users.router, prefix="/users", tags=["Users Management (RBAC)"])
api_router.include_router(admin.router, prefix="/admin", tags=["Admin Dashboard"])
api_router.include_router(vision.router, prefix="/vision", tags=["AI Vision (YOLOv8)"])
api_router.include_router(vocabulary.router, prefix="/vocabulary", tags=["Vocabulary & Mappings"])
api_router.include_router(notebook.router, prefix="/notebook", tags=["Vocabulary Notebook"])
api_router.include_router(skills.router, prefix="/skills", tags=["IELTS Skills"])
