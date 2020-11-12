from flask import Blueprint, redirect, render_template, session, escape, request, url_for
from flask_login import current_user, login_required, login_user
from __init__ import db, login_manager
from forms import *
from datetime import datetime, date, timedelta
from sqlalchemy import func


view = Blueprint("view", __name__)
#from tables import RecentBooking

## Creates a dictionary that handles logic across all pages.

def panel_filler(user_role,userid):
    panel = {'panel_ct':'','panel_po':'','profile':'/settings/','all_transact':'/transactions/'}
    if 'po' in user_role:
        panel['panel_po'] = panel['panel_ct'] + '/po_home'
    elif 'ptct' in user_role:
        panel['panel_ct'] = panel['panel_ct'] +'/pt_home'
    elif 'ftct' in user_role:
        panel['panel_ct'] = panel['panel_ct'] + '/ft_home'
    else: 
        raise Exception('ValueError: There is not information on the user')

    panel['profile'] = panel['profile'] + userid
    panel['all_transact'] = panel['all_transact'] + userid

    return panel
                

def get_user_role(userid):
    # query = 'SELECT user_type(\'{}\')'.format(userid)
    user_role = db.session.execute(func.user_type(userid)).fetchone()[0]
    roles = []
    if 1 & user_role:
        roles.append('po')
    if 2 & user_role:
        roles.append('ptct')
    if 4 & user_role:
        roles.append('ftct')
    return '/'.join(str(i) for i in roles)

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

@view.route("/registration-2",methods=["GET", "POST", "PUT", "DELETE"])
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
        podata = form.po_checkbox.data
        ctdata = form.ct_checkbox.data
        query1 = "INSERT INTO Accounts(userid,password) VALUES ('{}', '{}')".format(userid,password)
        db.session.execute(query1)
        db.session.commit()
        query2 = "INSERT INTO Users(userid, name, postal,address,hp, email) VALUES ('{}', '{}', '{}','{}', '{}', '{}')"\
            .format(userid,name,postal,address,hp,email)
        db.session.execute(query2)
        db.session.commit()
        roles = ''
        if podata:
            query = "INSERT INTO Pet_Owner(po_userid) VALUES ('{}')".format(userid)
            db.session.execute(query)
            db.session.commit()
            roles += 'po'
        if ctdata:
            query = "INSERT INTO Caretaker(ct_userid) VALUES ('{}')".format(userid)
            db.session.execute(query)
            db.session.commit()
            if roles:
                roles += '/'
            roles += 'ptct'
        session['user_role'] = roles
        session['panel'] = panel_filler(roles,userid)
        return redirect('/settings/{}'.format(userid))
    return render_template("registration-2.html",form = form)

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
            print(login_password)

            ## This equality will throw an error if the database is NOT loaded
            if login_password[0][0] == entered_password:
                fetch_name = "SELECT a.name FROM Users a WHERE userid ='{}' AND email = '{}'".format(userid,email)
                name = db.session.execute(fetch_name).fetchall()
                
                ##Updates Session
                session['name'] = name[0][0]
                session['userid'] = userid
                session['password'] = login_password[0][0]
                session['email'] = email

                user_role = get_user_role(userid)

                session['user_role'] = user_role
                user_role = user_role.split('/')
                
                session['panel'] = panel_filler(user_role,userid)

                if 'po' in user_role:
                    return redirect("/po_home")
                elif 'ptct' in user_role:
                    return redirect("/pt_home")
                elif 'ftct' in user_role:
                    return redirect("/ft_home")
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


@view.route("/settings/<userid>", methods =["GET","POST"])
def render_settings(userid):
    if 'userid' not in session:
        return redirect('login')
    user_role = session['user_role']
    return render_template("4_settings_profile.html")


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
    if 'user_role' not in session:
        user_role = get_user_role(userid)
        session['user_role'] = user_role
    user_role = session['user_role']
    if 'po' not in user_role:
        return redirect('/pt_home')
    #role_user = session['user_role']
    role_user = 'po'
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
        href = "\"/booking/"+ '/'.join(row[0][1:-1].split(",")) + '"'
        new = row[0][1:-1].split(",")
        new.append(href)
        print(new)
        table.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date', 'status','dead',"hrefstring"), new)))

    for item in ct:
        href = "/review_rating/"+ '/'.join(item[0][1:-1].split(","))
        new = item[0][1:-1].split(",")
        new.append(href)
        comp_trans.append(dict(zip(('pet_name','userid','start_date','end_date','dead','hrefstring'), new))) 
    
    session['panel'] = panel_filler(user_role,userid)
    panel = session["panel"]

    return render_template("/5_PO_home.html",form = form, \
                                            name = name, \
                                            table = table, \
                                            hp = hp,\
                                            email = email,\
                                            comp_trans = comp_trans,\
                                            ftpt = user_role,\
                                            panel = panel
                                            )

@view.route("/pt_home",methods=["GET", "POST"])
def render_pt_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
    
    name = session['name']

    #userid = session['userid']
    userid = 'aneildy' ## change this later
    if 'user_role' not in session:
        user_role = get_user_role(userid)
        session['user_role'] = user_role
    user_role = session['user_role']
    if 'ftct' in user_role:
        return redirect('/ft_home')
    elif 'ptct' not in user_role:
        return redirect('/po_home')

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


    return render_template("/12_PT_home.html", name = name,
        upcoming_jobs = upcoming_jobs,
        has_upcoming = (len(upcoming_jobs) > 0),
        pending_jobs = pending_jobs,
        has_pending = (len(pending_jobs) > 0))

@view.route("/ft_home",methods=["GET", "POST"])
def render_ft_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
        
    name = session['name']
    #userid = session['userid']
    userid = 'deverton82' ## change this later
    # if 'user_role' not in session:
    user_role = get_user_role(userid)
    session['user_role'] = user_role
    user_role = session['user_role']
    if 'ptct' in user_role:
        return redirect('/pt_home')
    elif 'ftct' not in user_role:
        return redirect('/po_home')

    ## need to create logic if 
    ## person is not caretaker 
    ## person is not PT caretaker
    ## person does not have any upcoming and pending jobs
    ## person does not have either one job
    data_upcoming = db.session.query(func.ftpt_upcoming(userid)).all()
    upcoming_jobs = []
    for row in data_upcoming:
        upcoming_jobs.append(dict(zip(('pet_name', 'userid', 'start_date', 'end_date'), row[0][1:-1].split(","))))
    
    return render_template("/12_FT_home.html", name = name,
        upcoming_jobs = upcoming_jobs,
        has_upcoming = (len(upcoming_jobs) > 0))

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


@view.route("/transactions/<userid>",methods = ["GET","POST"])
def render_transactions_page(userid):
    if 'userid' not in session:
        return redirect('/login')
    return render_template("/9_all_transactions.html")

@view.route("/PO_confirmation/<userid>/<pn>/<ct>/<sd>/<ed>/<d>", methods = ["GET", "POST"])
def render_PO_confirmation(userid,pn, ct, sd, ed, d):
    if 'userid' not in session:
        return redirect('/login')
    po_name = session['name']
    po_hp = db.session.query(func.find_hp('{}'.format(userid))).all()[0][0]
    petname = session['pet_name']
    pettype = db.session.query(func.find_pettype('{}'.format(userid, pet_name))).all()[0][0]
    special_req = db.session.query(func.find_specreq('{}'.format(userid, pet_name))).all()[0][0]
    ct_name = db.session.query(func.find_name('{}'.format(ct))).all()[0][0]
    ct_hp = db.session.query(func.find_hp('{}'.format(ct))).all()[0][0]
    sd = session["start_date"]
    ed = session["end_date"]
    diff = ed - sd + 1
    rate = db.session.query(func.find_rate('{}'.format(ct, pettype))).all()[0][0]
    price = rate * diff
    mthd = db.session.query(func.find_card('{}'.format(userid))).all()[0][0]
    return render_template("/7_PO_confirmation.html", po_name = po_name, po_hp = hp, petname = petname, pettype = pettype, special_req = special_req, ct_name = ct_name, ct_hp = ct_hp, diff = diff, rate = rate, price = price, mthd = mthd)

@view.route("/admin/AddFT", methods = ["GET", "POST"])
def render_addFT():
    form = AddFT()
    if form.validate_on_submit():
        userid = form.userid.data
        name = form.name.data
        password = form.password.data
        email = form.email.data
        postal = form.postal.data
        address = form.address.data
        hp = form.hp.data
        podata = form.po_checkbox.data
        ctdata = form.ct_checkbox.data

        check_user = "SELECT * FROM Users WHERE userid = '{}'".format(userid)
        exists_user = db.session.execute(check_user).fetchone()
        check_email = "SELECT * FROM Users WHERE email = '{}'".format(email)
        exists_email = db.session.execute(check_email).fetchone()
        if exists_user:
            form.userid.errors.append("{} is already in use.".format(userid))
        if exists_email:
            form.email.errors.append("{} is already in use.".format(email))
        query1 = "INSERT INTO Accounts(userid,password) VALUES ('{}', '{}')".format(userid,password)
        db.session.execute(query1)
        db.session.commit()
        query2 = "INSERT INTO Users(userid, name, postal,address,hp, email) VALUES ('{}', '{}', '{}','{}', '{}', '{}')"\
            .format(userid,name,postal,address,hp,email)
        db.session.execute(query2)
        db.session.commit()
        roles = ''
        if podata:
            query = "INSERT INTO Pet_Owner(po_userid) VALUES ('{}')".format(userid)
            db.session.execute(query)
            db.session.commit()
            roles += 'po'
        if ctdata:
            query = "INSERT INTO Caretaker(ct_userid, full_time) VALUES ('{}')".format(userid, TRUE)
            db.session.execute(query)
            db.session.commit()
            if roles:
                roles += '/'
            roles += 'ftct'
        session['user_role'] = roles
        session['panel'] = panel_filler(roles,userid)
        return redirect("/admin_home.html")
    return render_template("18_addFT.html", form=form)

