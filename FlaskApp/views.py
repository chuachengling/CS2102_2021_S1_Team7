from flask import Blueprint, redirect, render_template, session, escape, request, url_for
from flask_login import current_user, login_required, login_user
from __init__ import db, login_manager
from forms import *
from datetime import datetime, date, timedelta
from sqlalchemy import func


view = Blueprint("view",__name__)
#from tables import RecentBooking


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
    entered_password = form.password.data
    email = form.email.data
    if form.is_submitted():
        print("userid entered:", form.userid.data)
        print("password entered:", form.password.data)
    if form.validate_on_submit():
        exists_user = db.session.execute(func.login(userid,entered_password)).fetchall()  
        if exists_user:
            ## Checks if password is correct 
            login_pass ="SELECT a.password FROM Accounts a WHERE userid = '{}' AND password = '{}'".format(userid,entered_password)  ### Supposed to use function but currently function does not work. 
            login_password = db.session.execute(login_pass).fetchall()

            ## This equality will throw an error if the database is NOT loaded
            if login_password[0][0] == entered_password:
                fetch_name = "SELECT a.name FROM Users a WHERE userid ='{}' AND email = '{}'".format(userid,email)
                name = db.session.execute(fetch_name).fetchall()
                
                ##Updates Session
                session['name'] = name[0][0]
                session['userid'] = userid
                session['password'] = login_password[0][0]
                session['email'] = email

                #role_user = db.session.query(func.somefunc(userid)).fetchall()
                role_user = [(1,)]
                session['ftptpo'] = role_user[0]
                
                if role_user[0] == 1 or role_user[0] == 3 or role_user[0] == 5:
                    return redirect("/po_home")
                elif role_user[0] == 2 or role_user[0] == 4:
                    return redirect("/ct_home")
                else: 
                    return redirect("/registration")
            else:
                ## Need to think how to reset the page and tell user password is wrong
                return redirect("/reset")
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

@view.route("/registration-2",methods=["GET", "POST","PUT","DELETE"])
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
        poct = form.poct.data
        query1 = "INSERT INTO Accounts(userid,password) VALUES ('{}', '{}')".format(userid,password)
        db.session.execute(query1)
        db.session.commit()
        query2 = "INSERT INTO Users(userid, name, postal,address,hp, email) VALUES ('{}', '{}', '{}','{}', '{}', '{}')"\
            .format(userid,name,postal,address,hp,email)
        db.session.execute(query2)
        db.session.commit()
        return redirect('/settings/{}'.format(userid))
    return render_template("registration-2.html",form = form)


@view.route("/settings/<userid>", methods =["GET","POST"])
def render_settings(userid):
    if 'userid' not in session:
        return redirect('login')
    user_role = session['ftptpo']
    return render_template("4_settings_profile.html",form = form)


@view.route("/profile/<nickname>",methods=["GET", "POST"])
def render_profile(nickname):
    if 'userid' not in session:
        return redirect('/login')
    
    return render_template("profile.html")

@view.route("/po_home",methods=["GET", "POST"])
def render_po_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
    
    ## initialising information required in web page
    name = session['name']
    userid = session['userid']
    data = db.session.query(func.po_upcoming_bookings('{}'.format(userid))).all()
    email = session['email']
    hp = db.session.query(func.find_hp('{}'.format(userid))).all()[0][0]
    #role_user = session['ftptpo]
    role_user = 1
    ## completed transactions
    ct = db.session.query(func.pastTransactions('{}'.format(userid))).all()

    ## init display items
    table = []
    comp_trans = []

    ## Form stuff
    form = SearchDate()

    pet = []
    pet_data = db.session.query(func.find_pets('{}'.format(userid))).all()
    form.pet_name.choices = [(i[0], i[0]) for i in pet_data]

    start_date = form.startdate_field.data
    end_date = form.enddate_field.data
    pet_select = form.pet_name.data

    if form.validate_on_submit():
        session['start_date'] = start_date
        session['end_date'] = end_date
        session["pet_selected"] = pet_select
        return redirect('/search/{}/{}'.format(start_date,end_date))

    for row in data:
        href = "/booking/"+ '/'.join(row[0][1:-1].split(","))
        new = row[0][1:-1].split(",")
        new.append(href)
        print(new)
        table.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date', 'status','dead',"hrefstring"), new)))

    for item in ct:
        href = "/review_rating/"+ '/'.join(item[0][1:-1].split(","))
        new = item[0][1:-1].split(",")
        new.append(href)
        comp_trans.append(dict(zip(('pet_name','userid','start_date','end_date','dead','hrefstring'), new))) 

    return render_template("/5_PO_home.html",form = form, \
                                            name = name, \
                                            table = table, \
                                            hp = hp,\
                                            email = email,\
                                            comp_trans = comp_trans,\
                                            ftpt = role_user
                                            )


@view.route("/pt_home",methods=["GET", "POST"])
def render_pt_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
    
    name = session['name']
    #userid = session['userid']
    userid = 'lcorkella5' ## change this later

    ## need to create logic if 
    ## person is not caretaker 
    ## person is not PT caretaker
    ## person does not have any upcoming and pending jobs
    ## person does not have either one job

    data_upcoming = db.session.query(func.ftpt_upcoming(userid)).all()
    data_pending = db.session.query(func.ftpt_pending(userid)).all()
    upcoming_jobs = []
    pending_jobs = []
    for row in data_upcoming:
        upcoming_jobs.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date'), row[0][1:-1].split(","))))
    
    for row in data_pending:
        pending_jobs.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date'), row[0][1:-1].split(","))))


    return render_template("/12_PT_home.html",name = name,\
                                                upcoming_jobs = upcoming_jobs,\
                                                pending_jobs = pending_jobs)

@view.route("/ft_home",methods=["GET", "POST"])
def render_ft_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
        
    name = session['name']
    #userid = session['userid']
    userid = 'lcorkella5' ## change this later

    ## need to create logic if 
    ## person is not caretaker 
    ## person is not PT caretaker
    ## person does not have any upcoming and pending jobs
    ## person does not have either one job
    data_upcoming = db.session.query(func.ftpt_upcoming(userid)).all()
    upcoming_jobs = []
    for row in data_upcoming:
        upcoming_jobs.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date'), row[0][1:-1].split(","))))
    
    return render_template("/12_FT_home.html",name = name,\
                                                upcoming_jobs = upcoming_jobs) 


@view.route("/search/<start_date>/<end_date>",methods=["GET", "POST"])
def render_search(start_date,end_date):
    if 'userid' not in session:
        return redirect('/login')
    petname = session["pet_selected"]
    sd = session["start_date"]
    ed = session["end_date"]
    search_result = db.session.query(func.bid_search(petname,sd,ed)).all()
    result = [i[0] for i in search_result]
    ##need biddetails function to continue.
    return render_template("/6_PO_search.html",search_result = search_result)

@view.route("/booking/<pn>/<ct>/<sd>/<ed>/<st>/<d>", methods = ["GET","POST"])
def render_booking(pn,ct,sd,ed,st,d):
    if 'userid' not in session:
        return redirect('/login')

    userid = session['userid']
    
    return render_template("/8a_PO_confirmed_transaction.html")

@view.route("/review_rating/<pn>/<ct>/<sd>/<ed>/<d>",methods = ["GET","POST"])
def render_review_rating(pn,ct,sd,ed,d):
    if 'userid' not in session:
        return redirect('/login')
    return render_template("/11_review_rating.html")