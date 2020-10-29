from flask import Blueprint, redirect, render_template, session, escape, request
from flask_login import current_user, login_required, login_user
from flask_bootstrap import Bootstrap
from __init__ import db, login_manager
from forms import LoginForm, RegistrationForm, Registration2Form
view = Blueprint("view",__name__)
from sqlalchemy import func

@login_manager.user_loader
def load_user(userid):
    user = "SELECT u.userid FROM Users u WHERE userid = '{}'".format(userid)
    user = db.session.execute(user).fetchone()
    return user or current_user 


@view.route("/", methods=["GET"])
def render_dummy_page():
    if 'userid' in session:
        userid = session['userid']
        return redirect("/reset")
    return "<h1>CS2102</h1>\
    <h2>Flask App started successfully!</h2>\
        You are not logged in <br><a href = '/login'></b> + \
      click here to log in</b></a>"


@view.route("/registration", methods=["GET", "POST"])
def render_registration_page():
    form = RegistrationForm()
    if request.method == 'POST':
        session['userid'] = request.form['userid']
        session['name'] = request.form['name']
        session['email'] = request.form['email']
        session['password'] = request.form['password']

    if form.validate_on_submit():
        userid = form.userid.data
        name = form.name.data
        password = form.password.data
        email = form.email.data
        check_user = "SELECT * FROM Users WHERE userid = '{}'".format(userid)
        exists_user = db.session.execute(check_user).fetchone()
        check_email = "SELECT * FROM Users WHERE email = '{}'".format(email)
        exists_email = db.session.execute(check_email).fetchone()
        if exists_user:
            form.userid.errors.append("{} is already in use.".format(userid))
        if exists_email:
            form.email.errors.append("{} is already in use.".format(email))
        else:
            return redirect("/registration-2")
    return render_template("registration.html", form=form)


@view.route("/login", methods=["GET", "POST"])
def render_login_page():
    form = LoginForm()
    userid = form.userid.data
    if form.is_submitted():
        print("userid entered:", form.userid.data)
        print("password entered:", form.password.data)
    if form.validate_on_submit():
            user = "SELECT * FROM Users u WHERE userid = '{}'".format(userid)
            #db.session.         
            if user:
            # TODO: You may want to verify if password is correct
                login_user(user)
                #session['name'] = 
            return redirect("/home")
    return render_template("login.html",form = form)

@view.route('/logout')
def render_logout_page():
    session.pop('userid',None)
    return redirect('/')

@view.route("/privileged-page", methods=["GET"])
@login_required
def render_privileged_page():
    return "<h1>Hello, {}!</h1>".format(current_user.preferred_name or current_user.userid)

@view.route("/reset",methods = ["GET"])
def render_reset():
    return "<h1>Hello</h1>\
    <h2>Don't forget your userid or password!</h2>"

@view.route("/registration-2",methods=["GET", "POST"])
def render_setup_profile():
    form = Registration2Form()
    userid = session['userid']
    name = session['name']
    email = session['email']
    password = session['password']
    if form.validate_on_submit():
        postal = form.postal.data
        address = form.address.data
        hp = form.hp.data
        query1 = "INSERT INTO Accounts(userid,password) VALUES ('{}', '{}')".format(userid,password)
        db.session.execute(query1)
        db.session.commit()
        query2 = "INSERT INTO Users(userid, name, postal,address,hp, email) VALUES ('{}', '{}', '{}','{}', '{}', '{}')"\
            .format(userid,name,postal,address,hp,email)
        db.session.execute(query2)
        db.session.commit()
        return redirect('/home')
    return render_template("registration-2.html",form = form)

@view.route("/profile",methods=["GET", "POST"])
def render_profile():
    return render_template("profile.html")

@view.route("/home",methods=["GET", "POST"])
def render_dashboard():
    if 'user' not in session:
        redirect('/login')
    user_name = 'yourmother'
    #userid = session['userid']
    data = db.session.query(func.po_upcoming_bookings('spurseyh'))
    table = []

    for row in data:
        table.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date', 'status'), row[0][1:-1].split(","))))
        # table.append('<tr style="color: black">' + ''.join('<td>{}</td>'.format(i) for i in row) + '<td></td></tr>')
        # <tr style="color: black">
        #   <td><a href="16_Pet_profile.html">Xxxxxxxx</a></td>
        #   <td>caretaker_name</td>
        #   <td>DDMMYY</td>
        #   <td>DDMMYY</td>
        #   <td>PENDING</td>
        #   <td><a href="8_PO_confirm_chat.html" class="smallbtn">VIEW</a></td>
        # </tr>
    return render_template("/5_PO_home.html",user = user_name, table = table)

@view.route("/edit-profile",methods=["GET", "POST"])
def render_edit_profile():
    pass