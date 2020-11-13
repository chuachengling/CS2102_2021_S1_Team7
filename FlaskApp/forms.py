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
    )
    ct_checkbox = BooleanField(
        label='Care Taker',
        validators=[one_selected],
    )
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

## Page 4 Settings Form

class PersonalUpdateForm(FlaskForm):
    handphone_field = StringField(
        label='Update handphone number',
    )

    address_field = StringField(
        label='Update address'
    )

    password_field = PasswordField(
        label='Update password'
    )
    submit_field = SubmitField('Update personal data')

class AddPetForm(FlaskForm):
    petname_field = StringField(
        label='Pet name'
    )
    pettype_field = SelectField(
        label='Pet type',
        choices=[('Cat', 'Cat'), ('Dog', 'Dog'), ('Rabbit', 'Rabbit'), ('Guinea pig', 'Guinea pig'), ('Hamster', 'Hamster'), ('Gerbil', 'Gerbil'), ('Mouse', 'Mouse'), ('Chinchilla', 'Chinchilla')]
    )
    dob_field = DateField(
        label = 'Date of birth',
        format='%Y-%m-%d'
    )
    special_field = TextAreaField(
        label = 'Special requests'
    )
    submit_field = SubmitField('Add pet')

class FinanceUpdateForm(FlaskForm):
    bank_field = StringField(
        label='Bank account number'
    )
    credit_field = StringField(
        label='Credit card number'
    )
    cat_rate = StringField(label = 'Cat')
    dog_rate = StringField(label = 'Dog')
    rabbit_rate = StringField(label = 'Rabbit')
    guinea_rate = StringField(label = 'Guinea pig')
    hamster_rate = StringField(label = 'Hamster')
    gerbil_rate = StringField(label = 'Gerbil')
    mouse_rate = StringField(label = 'Mouse')
    chinchilla_rate = StringField(label = 'Chinchilla')
    submit_field = SubmitField('Update financial data')


## Page 5 Pet Owner Home Date Form
class SearchDate(FlaskForm):
    def validate_end_date_field(form,field):
        if form.startdate_field.data > form.enddate_field.data:
            raise ValidationError("Start date cannot be after end date!")
        if form.enddate_field.data - form.startdate_field.data > timedelta(days=14):
            raise ValidationError("Total length of booking cannot exceed 14 days")  
        if form.enddate_field.data < date.today():  
            raise ValidationError("Choose a valid end date!")
    
    def validate_start_date_field(form,field):
        if form.startdate_field.data < date.today():
            raise ValidationError("Choose a valid start date!")
    pet_name = SelectField(label = 'Pet Name',validators = [InputRequired()])
    startdate_field = DateField(label = 'Start Date', format='%Y-%m-%d',validators = [InputRequired(),validate_start_date_field])
    enddate_field = DateField(label = 'End Date', format='%Y-%m-%d',validators = [InputRequired(),validate_end_date_field])
    submit_field = SubmitField('Search')

## Page 11 Stars Form

class StarsForm(FlaskForm):
    review = TextAreaField(
        label='Review',
        validators=[InputRequired()],
        render_kw={'placeholder': 'Review'}
    )
    stars = RadioField(
        label='Stars',
        validators=[InputRequired()],
        choices = list(('{:02d}'.format(i*5), '{:02d}'.format(i*5)) for i in range(10, 0, -1))
    )
    submit = SubmitField("Submit")

## For page 13a FT Leave

class AddFT_leave(FlaskForm):
    leave_startdate_field = DateField(label = 'Start Date', format='%Y-%m-%d')
    leave_enddate_field = DateField(label = 'End Date', format='%Y-%m-%d')

    def validate_enddate_field(form, field):
        if field.data < form.leave_startdate_field.data:
            raise ValidationError("End date must not be earlier than start date.")
    
    def validate_leave_dates_field(form, field):
        if (datetime.now() + timedelta(days = 28)) < form.leave_startdate_field:
            raise ValidationError("You must apply for leave minimally one month (28 days) in advance") 
    submit_field = SubmitField("Apply leave")

## For page 13b PT Avail

class AddPT_avail(FlaskForm):
    avail_startdate_field = DateField(label = 'Start Date', format='%Y-%m-%d')
    avail_enddate_field = DateField(label = 'End Date', format='%Y-%m-%d')

    def validate_enddate_field(form, field):
        if field.data < form.avail_startdate_field.data:
            raise ValidationError("End date must not be earlier than start date.") 
    submit_field = SubmitField("Apply leave")


class MessageForm(FlaskForm):
    text_field = TextAreaField(validators = [InputRequired()])
    submit_field = SubmitField('Send')

class RejectForm(FlaskForm):
    reject_field = SubmitField('Reject')

class AcceptForm(FlaskForm):
    accept_field = SubmitField('Accept')

class CancelForm(FlaskForm):
    cancel_field = SubmitField('Cancel Booking')

class ConfirmForm(FlaskForm):
    confirm_field = SubmitField('Confirm Booking')


## Page 17 Admin Home Page

class Admin_modify_price(FlaskForm):
    cat_rate = StringField(label = 'Cat')
    dog_rate = StringField(label = 'Dog')
    rabbit_rate = StringField(label = 'Rabbit')
    guinea_rate = StringField(label = 'Guinea pig')
    hamster_rate = StringField(label = 'Hamster')
    gerbil_rate = StringField(label = 'Gerbil')
    mouse_rate = StringField(label = 'Mouse')
    chinchilla_rate = StringField(label = 'Chinchilla')
    submit_field = SubmitField('Update Base Price for Caretaking Service')

class Admin_stat_search(FlaskForm):
    month_field = SelectField(
        label = 'Month',
        choices =[(1, 'January'), (2, 'February'), (3, 'March'), (4, 'April'), (5, 'May'), (6, 'June'),
        (7, 'July'), (8, 'August'), (9, 'September'), (10, 'October'), (11, 'November'), (12, 'December')]
    )
    year_field = StringField(label = 'Year')
    submit_field = SubmitField('Search')

## Page 18 Add FT Form

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

    
    

#class ForgotForm(Form):
#    email = EmailField('Email address', [validators.DataRequired(),validators.Email()])

#class PasswordResetForm(FlaskForm):
#    current_password = PasswordField('Current Password', [val])