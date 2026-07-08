from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from datetime import datetime


class EnrollmentFormField(BaseModel):
    label: str
    type: str  # text, number, select, date
    required: bool = False
    options: Optional[List[str]] = None


class EnrollmentFormConfigBase(BaseModel):
    fields: List[EnrollmentFormField] = []
    require_images: bool = False
    image_count: int = 1
    image_instructions: Optional[str] = None


class EnrollmentFormConfigCreate(EnrollmentFormConfigBase):
    pass


class EnrollmentFormConfigResponse(EnrollmentFormConfigBase):
    id: str
    course_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class EnrollmentRequestImageResponse(BaseModel):
    id: str
    url: str
    created_at: datetime

    class Config:
        from_attributes = True


class EnrollmentRequestBase(BaseModel):
    course_id: str
    form_data: Dict[str, Any]


class EnrollmentRequestCreate(EnrollmentRequestBase):
    # Images will be handled via multipart/form-data or separate URLs
    image_urls: List[str] = []


class EnrollmentRequestResponse(BaseModel):
    id: str
    user_id: str
    course_id: str
    status: str
    form_data: Dict[str, Any]
    admin_comment: Optional[str] = None
    images: List[EnrollmentRequestImageResponse] = []
    created_at: datetime
    updated_at: datetime
    processed_at: Optional[datetime] = None
    processed_by: Optional[str] = None
    
    # Extra info for admin
    user_email: Optional[str] = None
    course_title: Optional[str] = None

    class Config:
        from_attributes = True
