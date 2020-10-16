from flask import Blueprint, redirect, render_template
from flask_login import current_user, login_required, login_user
from flask_bootstrap import Bootstrap
from __init__ import db, login_manager
from forms import LoginForm, RegistrationForm
from models import WebUser

view = Blueprint("view",__name__)


@login_manager.user_loader
def load_user(username):
    user = WebUser.query.filter_by(username=username).first()
    return user or current_user


@view.route("/", methods=["GET"])
def render_dummy_page():
    return "<h1>CS2102</h1>\
    <h2>Flask App started successfully!</h2>"


@view.route("/registration", methods=["GET", "POST"])
def render_registration_page():
    form = RegistrationForm()
    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data
        email = form.email.data
        check_user = "SELECT * FROM web_user WHERE username = '{}'".format(username)
        exists_user = db.session.execute(check_user).fetchone()
        check_email = "SELECT * FROM web_user WHERE email = '{}'".format(username)
        exists_email = db.session.execute(check_email).fetchone()
        if exists_user:
            form.username.errors.append("{} is already in use.".format(username))
        if exists_email:
            form.email.errors.append("{} is already in use.".format(username))
        else:
            query = "INSERT INTO web_user(username, preferred_name, password) VALUES ('{}', '{}', '{}')"\
                .format(username, email, password)
            db.session.execute(query)
            db.session.commit()
            return "You have successfully signed up!"
    return render_template("registration.html", form=form)


@view.route("/login", methods=["GET", "POST"])
def render_login_page():
    form = LoginForm()
    if form.is_submitted():
        print("username entered:", form.username.data)
        print("password entered:", form.password.data)
    if form.validate_on_submit():
        user = WebUser.query.filter_by(username=form.username.data).first()
        if user:
            # TODO: You may want to verify if password is correct
            login_user(user)
            return redirect("/setup-profile")
    return render_template("login.html",form = form)


@view.route("/privileged-page", methods=["GET"])
@login_required
def render_privileged_page():
    return "<h1>Hello, {}!</h1>".format(current_user.preferred_name or current_user.username)

@view.route("/reset",methods = ["GET"])
def render_reset():
    return "<h1>Hello</h1>\
    <h2>Don't forget your username or password!</h2>"

@view.route("/setup-profile",methods=["GET", "POST"])
def render_setup_profile():
    return render_template('setup_profile.html')

@view.route("/profile",methods=["GET", "POST"])
def render_profile():
    return render_template("profile.html")

@view.route("/dashboard",methods=["GET", "POST"])
def render_dashboard():
    return render_template("dashboard.html")