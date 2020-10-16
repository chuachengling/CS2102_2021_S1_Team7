from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField
from wtforms.validators import InputRequired, ValidationError, Email, Length



def is_valid_name(form, field):
    if not all(map(lambda char: char.isalpha(), field.data)):
        raise ValidationError('This field should only contain alphabets')

def agrees_terms_and_conditions(form, field):
    if not field.data:
        raise ValidationError('You must agree to the terms and conditions to sign up')

class RegistrationForm(FlaskForm):
    username = StringField(
        label='Name',
        validators=[InputRequired(), is_valid_name],
        render_kw={'placeholder': 'Name'}
    )
    password = PasswordField(
        label='Password',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Password'}
    )
    email = StringField(
        label='Email',
        validators=[InputRequired(), Email(message = 'Invalid email')],
        render_kw={'placeholder': 'Email'}
    )


class LoginForm(FlaskForm):
    username = StringField(
        label='Name',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Name', 'class': 'input100'}
    )
    password = PasswordField(
        label='Password',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Password', 'class': 'input100'}
    )

#class ForgotForm(Form):
#    email = EmailField('Email address', [validators.DataRequired(),validators.Email()])

#class PasswordResetForm(FlaskForm):
#    current_password = PasswordField('Current Password', [val])