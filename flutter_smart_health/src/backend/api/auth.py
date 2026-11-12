from __future__ import annotations

from fastapi import APIRouter, HTTPException

from src.backend.clients.ehospital_auth_client import authenticate_ehospital_user
from src.backend.schemas.auth import (
    LoginRequest,
    SendWhatsAppOtpRequest,
    VerifyWhatsAppOtpRequest,
)
from src.backend.services.otp_service import (
    generate_and_send_whatsapp_otp,
    verify_whatsapp_otp,
)

router = APIRouter(tags=["auth"])


@router.post("/login")
async def login(request: LoginRequest) -> dict:
    return await authenticate_ehospital_user(
        request.email,
        request.password,
        request.selectedOption,
    )


@router.post("/api/auth/whatsapp/send-otp")
@router.post("/auth/whatsapp/send-otp")
async def send_whatsapp_otp_endpoint(request: SendWhatsAppOtpRequest) -> dict:
    res = await generate_and_send_whatsapp_otp(request.phone)
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("error", "Failed to send OTP"))
    return res


@router.post("/api/auth/whatsapp/verify-otp")
@router.post("/auth/whatsapp/verify-otp")
async def verify_whatsapp_otp_endpoint(request: VerifyWhatsAppOtpRequest) -> dict:
    res = await verify_whatsapp_otp(
        request.phone,
        request.code,
        request.selectedOption,
    )
    if not res.get("authenticated"):
        raise HTTPException(
            status_code=400,
            detail=res.get("error", "Invalid or expired verification code"),
        )
    return res

