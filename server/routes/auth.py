
from fastapi import Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic_schemas.user_create import UserCreate
from pydantic_schemas.user_login import UserLogin
from models.user import User
from database import get_db
from fastapi import APIRouter
import uuid
import bcrypt
import jwt

from middleware.auth_middleware import auth_middleware


router = APIRouter()


@router.post("/signup", status_code=201)
def signup_user(user: UserCreate, db: Session = Depends(get_db)):
    user_db = db.query(User).filter(User.email == user.email).first()
    if user_db:
        raise HTTPException(status_code=400, detail="User with the same email already exists!")

    hashed_pw = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt())
    new_user = User(
        id=str(uuid.uuid4()),
        email=user.email,
        password=hashed_pw,
        name=user.name,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.post('/login')
def login_user(user: UserLogin, db: Session = Depends(get_db)):
    # check if a user with same email already exist
    user_db = db.query(User).filter(User.email == user.email).first()

    if not user_db:
        raise HTTPException(400, 'User with email does not exist!')

    # password matching or not
    is_match = bcrypt.checkpw(user.password.encode(), user_db.password)

    if not is_match:
        raise HTTPException(400, 'Incorrect password!')

    token = jwt.encode({'id': user_db.id}, 'password_key')

    return {'token': token, 'user': user_db} 

@router.get('/')
def current_user_data(db: Session = Depends(get_db), user_dict = Depends(auth_middleware)):
    user = db.query(User).filter(User.id == user_dict['uid']).first()

    if not user:
        raise HTTPException(404, 'User not found!')

    return user