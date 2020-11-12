from flask_wtf import FlaskForm
from wtforms import *
from wtforms.validators import InputRequired, ValidationError, Email, Length
from wtforms.fields.html5 import DateField

from datetime import datetime,date,timedelta



def is_valid_name(form, field):
    if not all(map(lambda char: char.isalnum() or char == ' ', field.data)):
        raise ValidationError('This field should only contain alphabets')

def agrees_terms_and_conditions(form, field):
    if not field.data:
        raise ValidationError('You must agree to the terms and conditions to sign up')
    
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

class MultiCheckboxField(SelectMultipleField):
    widget = widgets.ListWidget(prefix_label=False)
    option_widget = widgets.CheckboxInput()

class Registration2Form(FlaskForm):
    def one_selected(form, field):
        if not (form.po_checkbox.data or form.ct_checkbox.data):
            raise ValidationError('At least one role has to be selected!')

    address = StringField(
        label='Address',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Address'}
    )
    postal = StringField(
        label = 'Postal Code',
        validators = [Length(6, 6)],
        render_kw={'placeholder': 'Postal Code'}
    )
    hp = StringField(
        label='Handphone Number',
        validators=[Length(8, 8)],
        render_kw={'placeholder': 'Handphone Number'}
    )
    poct_label = Label(
        field_id='poct_label',
        text = 'I\'m signing up as a...'
    )
    po_checkbox = BooleanField(
        label='Pet Owner',
        validators=[one_selected],
        # render_kw={'placeholder': 'Pet Owner'}
    )
    ct_checkbox = BooleanField(
        label='Care Taker',
        validators=[one_selected],
        # render_kw={'placeholder': 'Pet Owner'}
    )

    # poct = MultiCheckboxField('Choose type',
    #                             choices = [(1,'Pet Owner'),(2,'Caretaker')],
    #                             coerce = int)

    submit = SubmitField("Submit")


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

class SearchDate(FlaskForm):
    pet_name = SelectField(label = 'Pet Name',validators = [InputRequired()])
    startdate_field = DateField(label = 'Start Date', format='%Y-%m-%d')
    enddate_field = DateField(label = 'End Date', format='%Y-%m-%d')
    submit_field = SubmitField('Search')

    def validate_enddate_field(form, field):
        if field.data < form.startdate_field.data:
            raise ValidationError("End date must not be earlier than start date.")
    
    def validate_length_field(form,field): ### still doesnt work, doing other things instead
        if field.data > form.startdate_field.data :
            raise ValidationError("Total length of booking cannot exceed 14 days")

#class ForgotForm(Form):
#    email = EmailField('Email address', [validators.DataRequired(),validators.Email()])

#class PasswordResetForm(FlaskForm):
#    current_password = PasswordField('Current Password', [val])

class AddFT(FlaskForm):
    def one_selected(form, field):
        if not (form.po_checkbox.data or form.ct_checkbox.data):
            raise ValidationError('At least one role has to be selected!')
    userid = StringField(
        label='Username',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Employee_Username'}
    )
    name = StringField(
        label = 'Name',
        validators = [InputRequired(), is_valid_name],
        render_kw={'placeholder': 'Employee_Name'}
    )
    email = StringField(
        label='Email',
        validators=[InputRequired(), Email(message = 'Invalid email')],
        render_kw={'placeholder': 'Employee_Email'}
    )
    password = PasswordField(
        label='Password',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Employee_Password'}
    )
    address = StringField(
        label='Address',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Employee_Address'}
    )
    postal = StringField(
        label = 'Postal Code',
        validators = [InputRequired()],
        render_kw={'placeholder': 'Employee_Postal Code'}
    )
    hp = StringField(
        label='Handphone Number',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Employee_Handphone Number'}
    )

    poct_label = Label(
        field_id='poct_label',
        text = 'I\'m signing up as a...'
    )
    po_checkbox = BooleanField(
        label='Pet Owner',
        validators=[one_selected],
        # render_kw={'placeholder': 'Pet Owner'}
    )
    ct_checkbox = BooleanField(
        label='Care Taker',
        validators=[one_selected],
        # render_kw={'placeholder': 'Pet Owner'}
    )
    submit = SubmitField("Sign Up")