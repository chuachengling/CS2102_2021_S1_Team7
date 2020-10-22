from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, SubmitField
from wtforms.validators import InputRequired, ValidationError, Email, Length



def is_valid_name(form, field):
    if not all(map(lambda char: char.isalnum() or char == ' ', field.data)):
        raise ValidationError('This field should only contain alphabets')

def agrees_terms_and_conditions(form, field):
    if not field.data:
        raise ValidationError('You must agree to the terms and conditions to sign up')

class Registration2Form(FlaskForm):
    address = StringField(
        label='Address',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Address'}
    )
    postal = StringField(
        label = 'Postal Code',
        validators = [InputRequired()],
        render_kw={'placeholder': 'Postal Code'}
    )
    hp = StringField(
        label='Handphone Number',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Handphone Number'}
    )
    submit = SubmitField("Submit")
    
class RegistrationForm(FlaskForm):
    userid = StringField(
        label='Username',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Username'}
    )
    name = StringField(
        label = 'Name',
        validators = [InputRequired(), is_valid_name],
        render_kw={'placeholder': 'Name'}
    )
    email = StringField(
        label='Email',
        validators=[InputRequired(), Email(message = 'Invalid email')],
        render_kw={'placeholder': 'Email'}
    )
    password = PasswordField(
        label='Password',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Password'}
    )
    submit = SubmitField("Sign Up")

class LoginForm(FlaskForm):
    userid = StringField(
        label='Username',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Username'}
    )
    email = StringField(
        label='Email',
        validators=[InputRequired(), Email(message = 'Invalid email')],
        render_kw={'placeholder': 'Email'}
    )
    password = PasswordField(
        label='Password',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Password'}
    )
    submit = SubmitField("Submit")

#class ForgotForm(Form):
#    email = EmailField('Email address', [validators.DataRequired(),validators.Email()])

#class PasswordResetForm(FlaskForm):
#    current_password = PasswordField('Current Password', [val])