from flask import Blueprint, redirect, render_template, session, escape, request, url_for
from flask_login import current_user, login_required, login_user
from __init__ import db, login_manager
from forms import *
from datetime import datetime, date, timedelta
from sqlalchemy import func
import csv

view = Blueprint("view", __name__)

## Auxillary Functions

## Creates a dictionary that handles logic across all pages.

def panel_filler(user_role,userid):
    panel = {'panel_ct':'','panel_po':'','profile':'/settings','all_transact':'/transactions'}
    if 'po' in user_role and 'ptct' in user_role:
        panel['panel_po'] = '/po_home'
        panel['panel_ct'] = '/pt_home'
    elif 'po' in user_role and 'ftct' in user_role:
        panel['panel_po'] = '/po_home'
        panel['panel_ct'] = '/ft_home'
    elif 'po' in user_role:
        panel['panel_po'] = panel['panel_ct'] + '/po_home'
    elif 'ptct' in user_role:
        panel['panel_ct'] = panel['panel_ct'] +'/pt_home'
    elif 'ftct' in user_role:
        panel['panel_ct'] = panel['panel_ct'] + '/ft_home'
    elif 'admin' in user_role:
        pass
    else: 
        raise Exception('ValueError: There is no information on the user')

    panel['profile'] = panel['profile'] 
    panel['all_transact'] = panel['all_transact']

    return panel
                

def get_user_role(userid):
    user_role = db.session.execute(func.user_type(userid)).fetchone()[0]
    query = "SELECT COUNT(*) FROM admin WHERE userid = \'{}\'".format(userid)
    is_admin = db.session.execute(query).fetchone()[0] > 0
    roles = []
    if 1 & user_role:
        roles.append('po')
    if 2 & user_role:
        roles.append('ptct')
    if 4 & user_role:
        roles.append('ftct')
    if is_admin:
        roles.append('admin')
    return '/'.join(str(i) for i in roles)


## Testing whether flaskapp is working (can delete)
@view.route("/", methods=["GET"])
def render_dummy_page():
    if 'userid' in session:
        userid = session['userid']
        return redirect("/reset")
    return "<h1>CS2102</h1>\
    <h2>Flask App started successfully!</h2>\
        You are not logged in <br><a href = '/login'></b> + \
      click here to log in</b></a>"

## Page 1a Registration 1
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

## Page 2 Registration 2

@view.route("/registration-2",methods=["GET", "POST", "PUT", "DELETE"])
def render_setup_profile():
    if 'userid' not in session:
        return redirect('/registration')
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
        session.pop('password')
        session.pop('email')
        session.pop('name')
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
        session['panel'] = panel_filler(roles,userid)
        return redirect('/settings')
    return render_template("registration-2.html",form = form)

## Page 3 Login

@view.route("/login", methods=["GET", "POST"])
def render_login_page():
    form = LoginForm()
    userid = form.userid.data
    entered_password = form.password.data
    if form.validate_on_submit():
        exists_user = db.session.execute(func.login(userid,entered_password)).fetchone()[0]  
        if exists_user:
            ##Updates Session
            session['userid'] = userid
            user_role = get_user_role(userid)

            query = "SELECT COUNT(*) FROM admin WHERE userid = \'{}\'"
            is_admin = db.session.execute(query).fetchone()[0] > 0

            ## Handles panel page redirection                
            session['panel'] = panel_filler(user_role,userid)

            if 'po' in user_role:
                return redirect("/po_home")
            elif 'ptct' in user_role:
                return redirect("/pt_home")
            elif 'ftct' in user_role:
                return redirect("/ft_home") 
            elif 'admin' in user_role:
                return redirect("/admin_home")
            else: 
                return redirect("/registration")    
        else:
            ## Need to think how to reset the page and tell user password is wrong
            return redirect("/login")
    return render_template("login.html",form = form)

## Page 4 edit settings page

@view.route("/settings", methods =["GET","POST"])
def render_settings():
    if 'userid' not in session:
        return redirect('login')
    panel = session['panel']
    userid = session['userid']
    user_role = get_user_role(userid)
    name = db.session.query(func.find_name(userid)).all()[0][0]

    personal_form = PersonalUpdateForm()
    add_pet_form = AddPetForm()
    finance_form = FinanceUpdateForm()
    pairs = [('Cat', finance_form.cat_rate), ('Dog', finance_form.dog_rate), ('Rabbit', finance_form.rabbit_rate), ('Guinea pig', finance_form.guinea_rate),
        ('Hamster', finance_form.hamster_rate), ('Gerbil', finance_form.gerbil_rate), ('Mouse', finance_form.mouse_rate), ('Chinchilla', finance_form.chinchilla_rate)]

    if 'handphone_field' in request.form:
        if personal_form.handphone_field.data:
            hp = personal_form.handphone_field.data
            if all('0' <= i <= '9' for i in hp) and len(hp) == 8:
                query = 'UPDATE Users SET hp = \'{}\' WHERE userid = \'{}\''.format(hp, userid)
                db.session.execute(query)
                db.session.commit()
        if personal_form.address_field.data:
            query = 'UPDATE Users SET address = \'{}\' WHERE userid = \'{}\''.format(personal_form.address_field.data, userid)
            db.session.execute(query)
            db.session.commit()
        if personal_form.password_field.data:
            query = 'UPDATE Accounts SET password = \'{}\' WHERE userid = \'{}\''.format(personal_form.password_field.data, userid)
            db.session.execute(query)
            db.session.commit()
        return redirect('/settings')
    elif 'petname_field' in request.form:
        # TODO: Check if name already exists in there
        db.session.execute(func.addPOpets(userid, add_pet_form.petname_field.data, add_pet_form.dob_field.data, add_pet_form.special_field.data, add_pet_form.pettype_field.data))
        db.session.commit()
        return redirect('/settings')
    elif 'bank_field' in request.form:
        if finance_form.bank_field.data:
            bank = finance_form.bank_field.data
            if all('0' <= i <= '9' for i in bank) and len(bank) == 10:
                db.session.execute(func.editBank(userid, bank))
                db.session.commit()
        if finance_form.credit_field.data:
            credit = finance_form.credit_field.data
            if all('0' <= i <= '9' for i in credit) and len(credit) == 16:
                db.session.execute(func.editCredit(userid, credit))
                db.session.commit()
        for animal, field in pairs:
            if field.data:
                try:
                    price = float(field.data)
                except:
                    continue
                if 'ptct' in user_role:
                    db.session.execute(func.deletePTPetsICanCare(userid, animal))
                    if price > 0:
                        db.session.execute(func.addPTPetsICanCare(userid, animal, price))
                elif 'ftct' in user_role:
                    db.session.execute(func.deleteFTPetsICanCare(userid, animal))
                    if price > 0:
                        db.session.execute(func.addFTPetsICanCare(userid, animal))
                db.session.commit()

        return redirect('/settings')

    existingPrices = []
    for animal, _ in pairs:
        valid = db.session.execute(func.find_valid(userid, animal)).fetchone()[0]
        if valid:
            price = '${:.02f}'.format(db.session.execute(func.find_rate(userid, animal)).fetchone()[0])
        existingPrices.append(price if valid else '0')

    all_pets = db.session.query(func.all_POpets_deets(userid)).all() # (pet_name VARCHAR, pet_type VARCHAR, dob DATE, special_req VARCHAR)
    table = list()
    for row in all_pets:
        d = {}
        new = list(csv.reader([row[0][1:-1]]))[0]
        d["pn"] = new[0]
        d["p_type"] = new[1]
        d["dob"] = new[2]
        d["special_req"] = new[3]
        href = "/settings/remove_pet/" + new[0]
        d["href"] = href
        table.append(d)
    return render_template("4_settings_profile.html",
        name = name,
        table = table,
        personal_form = personal_form,
        add_pet_form = add_pet_form,
        finance_form = finance_form,
        is_po = 'po' in user_role,
        is_ptct = 'ptct' in user_role,
        is_ftct = 'ftct' in user_role,
        panel = panel,
        **dict(zip((i[0].replace(' ', '_') for i in pairs), existingPrices))
    )

@view.route("/deleteacc")
def render_delete():
    if 'userid' not in session:
        return redirect('login') 
    db.session.execute(func.deleteacc(session['userid']))
    db.session.commit()
    return redirect('/login')


@view.route("/settings/remove_pet/<pn>", methods = ["GET", "POST"])
def render_remove_pet(pn):
    if 'userid' not in session:
        return redirect('login') ##TODO check relative URL path
    userid = session['userid']
    db.session.execute(func.removePOpet(userid, pn))
    db.session.commit()
    return redirect('/settings')

# This may be useless
# @view.route("/profile/<nickname>",methods=["GET", "POST"])
# def render_profile(nickname):
#     if 'userid' not in session:
#         return redirect('/login')
#     return render_template("profile.html")


## Page 5 Pet owner home screen

@view.route("/po_home/",methods=["GET", "POST"])
def render_po_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
    
    ## initialising information required in web page
    panel = session['panel']
    userid = session['userid']
    name = db.session.query(func.find_name(userid)).all()[0][0]
    data = db.session.query(func.po_upcoming_bookings('{}'.format(userid))).all()
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
        return redirect('/search/{}/{}/{}'.format(pet_select,start_date,end_date))

    for row in data:
        row = row[0][1:-1].split(",")

        href = "/po_booking/" + '/'.join([row[0]] + row[2:5] + [row[6]])

        row.append(href)
        "/po_booking/<pn>/<ct>/<sd>/<ed>/<d>"

        table.append(dict(zip(('pet_name', 'name', 'ct_userid', 'start_date', 'end_date', 'status','dead',"hrefstring"), row)))

    for item in ct:
        row = item[0][1:-1].split(",")
        href = "/write_review_rating/{}/{}/{}/{}/{}".format(row[3], row[2], row[5], row[6], row[4])
        row.append(href)
        comp_trans.append(dict(zip(('po_name', 'name', 'ct_userid', 'pet_name', 'dead', 'start_date', 'end_date', 'hrefstring'), row))) 

    return render_template("/5_PO_home.html",form = form, \
                                            name = name, \
                                            table = table, \
                                            comp_trans = comp_trans,\
                                            panel = panel
                                            )

## Page 6 Search Results for Pet Owner

@view.route("/search/<pet_name>/<start_date>/<end_date>",methods=["GET", "POST"])
def render_search(pet_name,start_date,end_date):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    search_result = db.session.query(func.bid_search(userid,pet_name,start_date,end_date)).all()
    result = [i[0] for i in search_result]
    store = []
    for row in result:
        biddetails = db.session.query(func.bidDetails(row,userid,pet_name)).all()[0]
        new = biddetails[0][1:-1].split(",")
        hrefpast = "/ct_review/" + row
        hrefbook = "/po_ar_booking/" + pet_name +"/"+ row + "/" + start_date + "/" + end_date + "/" + "0"
        new.append(hrefpast)
        new.append(hrefbook)
        store.append(dict(zip(('name','avg_rating','ppd','hrefpast','hrefbook'), new))) 
    return render_template("/6_PO_search.html",search_result = search_result,\
                                                store = store,
                                                panel = panel)


## Page 7a Pet Owner Accept Reject booking NO CHAT
@view.route("/po_ar_booking/<pn>/<ct>/<sd>/<ed>/<d>", methods = ["GET","POST"])
def render_po_ar_booking(pn,ct,sd,ed,d):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']

    cancel_form = CancelForm()
    confirm_form = ConfirmForm()

    if cancel_form.cancel_field.data and cancel_form.validate_on_submit():
        return redirect('/po_home')
    
    # cdebneyda | aneildy   | Monroty  |    0 | 2020-10-05 | 2020-10-05
    # /po_ar_booking/Monroty/aneildy/2020-11-05/2020-11-05/0

    po_name = db.session.query(func.find_name(userid)).all()[0][0]
    po_hp = db.session.query(func.find_hp('{}'.format(userid))).all()[0][0]
    pettype = db.session.query(func.find_pettype(userid, pn, d)).all()[0][0]
    special_req = db.session.query(func.find_specreq(userid, pn, d)).all()[0][0]
    ct_name = db.session.query(func.find_name('{}'.format(ct))).all()[0][0]
    ct_hp = db.session.query(func.find_hp('{}'.format(ct))).all()[0][0]
    diff = (date(*(int(i) for i in ed.split('-'))) - date(*(int(i) for i in sd.split('-')))).days + 1
    rate = '{:.02f}'.format(float(db.session.query(func.find_rate(ct, pettype)).all()[0][0]))
    price = '{:.02f}'.format(float(rate) * diff)
    mthd = db.session.query(func.find_card('{}'.format(userid))).all()[0][0]
    mthd = ('Credit Card' if mthd != '0' else 'Cash')

    # SELECT applyBooking('cdebneyda', 'Monroty', 0, 'aneildy', '2020-11-05', '2020-11-05', 'Credit card')

    if confirm_form.confirm_field.data and confirm_form.validate_on_submit():
        db.session.execute(func.applyBooking(userid, pn, d, ct, sd, ed, mthd))
        db.session.commit()
        return redirect('/po_booking/{}/{}/{}/{}/{}'.format(pn, ct, sd, ed, d))

    return render_template("/7_PO_confirmation.html",
        po_name = po_name,
        po_hp = po_hp,
        petname = pn,
        pettype = pettype,
        special_req = special_req,
        ct_name = ct_name,
        ct_hp = ct_hp,
        diff = diff,
        rate = rate,
        price = price,
        mthd = mthd,
        sd = sd,
        ed = ed,
        cancel_form = cancel_form,
        confirm_form = confirm_form,
        panel = panel
    )

## Page 7b Caretaker Accept/Reject Page WITH CHAT
@view.route("/ct_ar_booking/<pn>/<po>/<sd>/<ed>/<d>", methods = ["GET","POST"])
def render_ct_ar_booking(pn,po,sd,ed,d):

    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    message_form = MessageForm()
    reject_form = RejectForm()
    accept_form = AcceptForm()

    if message_form.text_field.data and message_form.validate_on_submit():
        text = message_form.text_field.data
        query = 'INSERT INTO Chat VALUES (\'{}\', \'{}\', \'{}\', {}, \'{}\', \'{}\', \'{}\', 2, \'{}\')'.format(
            po, userid, pn, d, sd, ed, str(datetime.now()).split('.')[0] + '+08', text
        )
        db.session.execute(query)
        db.session.commit()
        return redirect('/ct_booking/{}/{}/{}/{}/{}'.format(pn, po, sd, ed, d))
    elif reject_form.reject_field.data and reject_form.validate_on_submit():
        query = 'UPDATE Looking_After SET status = \'Rejected\' WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}'.format(pn, po, userid, sd, ed, d)
        db.session.execute(query)
        db.session.commit()
        return redirect('/ct_booking/{}/{}/{}/{}/{}'.format(pn, po, sd, ed, d))
    elif accept_form.accept_field.data and accept_form.validate_on_submit():
        query = 'UPDATE Looking_After SET status = \'Accepted\' WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}'.format(pn, po, userid, sd, ed, d)
        db.session.execute(query)
        db.session.commit()
        return redirect('/ct_booking/{}/{}/{}/{}/{}'.format(pn, po, sd, ed, d))

    #   wroparsdp    | aneildy     | Tallity  |    0 | 2020-11-12 | 2020-11-12
    # /ct_ar_booking/Tallity/wroparsdp/2020-11-12/2020-11-12/0

    ctname = db.session.query(func.find_name(userid)).all()[0][0]
    name = db.session.query(func.find_name(po)).all()[0][0]
    pet_type = db.session.query(func.find_pettype(po, pn, d)).all()[0][0]
    duration = (date(*(int(i) for i in ed.split('-'))) - date(*(int(i) for i in sd.split('-')))).days + 1
    query = "SELECT status, trans_pr, payment_op FROM Looking_After WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, po, userid, sd, ed, d)
    status, trans_pr, payment_op = db.session.execute(query).fetchone()

    query = "SELECT * FROM Chat WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, po, userid, sd, ed, d)
    chat_log = db.session.execute(query).fetchall()
    
    chat_text = []
    for c in chat_log:
        sender = int(c[7])-1
        chat_text.append('{}: {}'.format((c[0], c[1], 'Admin')[sender], c[8]))

    return render_template("/8_PO_confirm_chat.html",
        name = name,
        hp = db.session.query(func.find_hp(po)).all()[0][0],
        petname = pn,
        pet_type = pet_type,
        spec_req = db.session.query(func.find_specreq(userid, pn, d)).all()[0][0],
        ctname = ctname,
        ctnum = db.session.query(func.find_hp(userid)).all()[0][0],
        start_date = str(sd),
        end_date = str(ed),
        duration = duration,
        rate = '{:.02f}'.format(round(trans_pr/duration, 2)),
        total = '{:.02f}'.format(round(trans_pr, 2)),
        status = status,
        payment_op = payment_op,
        chat_text = '\n\n'.join(chat_text),
        form = message_form,
        reject_form = reject_form,
        accept_form = accept_form,
        panel = panel
    ) ## TODO pet profile link

## Page 8a Pet Owner Confirmed booking page ## Pet Owner Sending Message
@view.route("/po_booking/<pn>/<ct>/<sd>/<ed>/<d>", methods = ["GET","POST"])
def render_po_booking(pn,ct,sd,ed,d):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    message_form = MessageForm()

    if message_form.validate_on_submit():
        text = message_form.text_field.data ##if you see 1 it's pet owner sending
        query = 'INSERT INTO Chat VALUES (\'{}\', \'{}\', \'{}\', {}, \'{}\', \'{}\', \'{}\', 1, \'{}\')'.format(
            userid, ct, pn, d, sd, ed, str(datetime.now()).split('.')[0] + '+08', text
        )
        db.session.execute(query)
        db.session.commit()
        return redirect('/po_booking/{}/{}/{}/{}/{}'.format(pn, ct, sd, ed, d))
    #  cidiens9a | aneildy   | Bernharty |    0 | 2020-10-11 | 2020-10-11
    # /booking/Bernharty/aneildy/2020-10-11/2020-10-11/0

    #  ahansemannnx | aneildy   | Nissty    |    0 | 2020-11-18 | 2020-11-20
    # /booking/Nissty/aneildy/2020-11-18/2020-11-20/0

    name = db.session.query(func.find_name(userid)).all()[0][0]
    ctname = db.session.query(func.find_name(ct)).all()[0][0]
    pet_type = db.session.query(func.find_pettype(userid, pn, d)).all()[0][0]
    duration = (date(*(int(i) for i in ed.split('-'))) - date(*(int(i) for i in sd.split('-')))).days + 1
    query = "SELECT status, trans_pr, payment_op FROM Looking_After WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, userid, ct, sd, ed, d)
    status, trans_pr, payment_op = db.session.execute(query).fetchone()

    query = "SELECT * FROM Chat WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, userid, ct, sd, ed, d)
    chat_log = db.session.execute(query).fetchall()
    
    chat_text = []
    for c in chat_log:
        sender = int(c[7])-1
        chat_text.append('{}: {}'.format((c[0], c[1], 'Admin')[sender], c[8]))

    return render_template("/8a_PO_confirmed_transaction.html",
        name = name,
        hp = db.session.query(func.find_hp(userid)).all()[0][0],
        petname = pn,
        pet_type = pet_type,
        spec_req = db.session.query(func.find_specreq(userid, pn, d)).all()[0][0],
        ctname = ctname,
        ctnum = db.session.query(func.find_hp(ct)).all()[0][0],
        start_date = str(sd),
        end_date = str(ed),
        duration = duration,
        rate = round(trans_pr/duration, 2),
        total = round(trans_pr, 2),
        status = status,
        payment_op = payment_op,
        chat_text = '\n\n'.join(chat_text),
        form = message_form,
        panel = panel
    ) ## TODO pet profile link

##Page  8b Caretaker Confirmed Booking Page
@view.route("/ct_booking/<pn>/<po>/<sd>/<ed>/<d>", methods = ["GET","POST"])
def render_ct_booking(pn,po,sd,ed,d):

    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    message_form = MessageForm()
    if message_form.validate_on_submit():
        text = message_form.text_field.data ##if you see 2 its caretaker sending
        query = 'INSERT INTO Chat VALUES (\'{}\', \'{}\', \'{}\', {}, \'{}\', \'{}\', \'{}\', 2, \'{}\')'.format(
            po, userid, pn, d, sd, ed, str(datetime.now()).split('.')[0] + '+08', text
        )
        db.session.execute(query)
        db.session.commit()
        return redirect('/ct_booking/{}/{}/{}/{}/{}'.format(pn, po, sd, ed, d))
    #   wroparsdp    | aneildy     | Tallity  |    0 | 2020-11-12 | 2020-11-12
    # /ct_booking/Tallity/wroparsdp/2020-11-12/2020-11-12/0

    ctname = db.session.query(func.find_name(userid)).all()[0][0]
    name = db.session.query(func.find_name(po)).all()[0][0]
    pet_type = db.session.query(func.find_pettype(po, pn, d)).all()[0][0]
    duration = (date(*(int(i) for i in ed.split('-'))) - date(*(int(i) for i in sd.split('-')))).days + 1
    query = "SELECT status, trans_pr, payment_op FROM Looking_After WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, po, userid, sd, ed, d)
    status, trans_pr, payment_op = db.session.execute(query).fetchone()

    query = "SELECT * FROM Chat WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, po, userid, sd, ed, d)
    chat_log = db.session.execute(query).fetchall()
    
    chat_text = []
    for c in chat_log:
        sender = int(c[7])-1
        chat_text.append('{}: {}'.format((c[0], c[1], 'Admin')[sender], c[8]))

    return render_template("/8a_PO_confirmed_transaction.html",
        name = name,
        hp = db.session.query(func.find_hp(po)).all()[0][0],
        petname = pn,
        pet_type = pet_type,
        spec_req = db.session.query(func.find_specreq(userid, pn, d)).all()[0][0],
        ctname = ctname,
        ctnum = db.session.query(func.find_hp(userid)).all()[0][0],
        start_date = str(sd),
        end_date = str(ed),
        duration = duration,
        rate = '{:.02f}'.format(round(trans_pr/duration, 2)),
        total = '{:.02f}'.format(round(trans_pr, 2)),
        status = status,
        payment_op = payment_op,
        chat_text = '\n\n'.join(chat_text),
        form = message_form,
        panel = panel
    ) ## TODO pet profile link

## Page 9 All transactions

## Check 7 and 8 linking TODO: 
@view.route("/transactions",methods = ["GET","POST"])
def render_transactions_page():
    #session['userid'] = 'deverton82'
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    all_transac = db.session.query(func.all_your_transac(userid)).all()
    # (ct_userid 0, po_userid 1, pet_name 2, dead 3, start_date 4, end_date 5, status 6, rating 7)
    table = list()
    for row in all_transac:
        new = list(csv.reader([row[0][1:-1]]))[0]
        if new[7] == 'NULL' and new[6] == 'Completed' and new[1] == userid: # po is me --> completed transaction yet to be reviewed
            href = "/write_review_rating/"+'/'.join((new[1], new[2],new[0],new[4], new[5], new[3]))
           # <userid>"/<pn>/<ct>/<sd>/<ed>/<d>"
           # + '/'.join(row[0][1:-1].split(","))
        elif new[1] == userid: # po is me --> show po_booking
            href = "/po_booking/" +'/'.join((new[2], new[0], new[4], new[5], new[3]))
            #<pn>/<ct>/<sd>/<ed>/<st>/<d>
        elif new[0] == userid: # ct is me --> show ct_booking
            href = '/ct_booking/' + '/'.join((new[2], new[1], new[4], new[5], new[3]))
        new[0] = db.session.query(func.find_name(new[0])).all()[0][0] # ct_name
        new[1] = db.session.query(func.find_name(new[1])).all()[0][0] # po_name
        new.append(href)
        table.append(dict(zip(('ct_name','po_name', 'pet_name', 'dead','start_date', 'end_date', 'status', 'rating', 'hrefstring'), new))) # completed and not reviewed -> review booking ELSE view booking
    return render_template("/9_all_transactions.html", table = table,panel = panel)



## Page 10 Caretaker Review

@view.route("/ct_review/<ct_userid>",methods = ["GET","POST"])
def render_ct_review(ct_userid):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    search_result = db.session.query(func.ct_reviews(ct_userid)).all()
    table = []
    for row in search_result:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new = new[1:]
        new[0] = db.session.query(func.find_name(new[0])).all()[0][0]
        new = new[:4] + new[5:]
        table.append(dict(zip(('userid', 'pet_name', 'start_date', 'end_date','rating',"review"), new)))
    return render_template("/10_CT_review.html", table = table,
                                                    panel = panel)

## Page 11 Write Review Ratings

@view.route("/write_review_rating/<pn>/<ct>/<sd>/<ed>/<d>",methods = ["GET","POST"])
def render_review_rating(pn,ct,sd,ed,d):
    if 'userid' not in session: 
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    pet_type = db.session.query(func.find_pettype(userid, pn, d)).all()[0][0]
    duration = (date(*(int(i) for i in ed.split('-'))) - date(*(int(i) for i in sd.split('-')))).days + 1
    query = "SELECT status, trans_pr, payment_op FROM Looking_After WHERE pet_name = \'{}\' AND po_userid = \'{}\' AND ct_userid = \'{}\' AND start_date = \'{}\' AND end_date = \'{}\' AND dead = {}".format(pn, userid, ct, sd, ed, d)
    status, trans_pr, payment_op = db.session.execute(query).fetchone()
    
    form = StarsForm()

    if form.validate_on_submit():
        given_rating = int(form.stars.data)/10
        written_review= form.review.data
        query = "UPDATE Looking_After la SET rating={}, review='{}' WHERE la.po_userid = '{}' AND la.ct_userid = '{}' AND la.start_date = '{}' AND la.end_date = '{}' AND la.pet_name = '{}' AND la.dead = {}".format(given_rating, written_review, userid, ct,sd,ed,pn,d)
        db.session.execute(query)
        db.session.commit()
        return redirect('/po_home')
    
    return render_template("/11_review_rating.html",
        name = db.session.query(func.find_name(userid)).all()[0][0],
        hp = db.session.query(func.find_hp(userid)).all()[0][0],
        petname = pn,
        pet_type = pet_type,
        spec_req = db.session.query(func.find_specreq(userid, pn, d)).all()[0][0],
        ctname = db.session.query(func.find_name(ct)).all()[0][0],
        ctnum = db.session.query(func.find_hp(ct)).all()[0][0],
        start_date = str(sd),
        end_date = str(ed),
        duration = duration,
        rate = round(trans_pr/duration, 2), ##TODO format
        total = round(trans_pr, 2),
        status = status,
        payment_op = payment_op,
        form = form,
        panel = panel
    )

## Page 12a Full time caretaker home page 
@view.route("/ft_home",methods=["GET", "POST"])
def render_ft_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
    userid = session['userid']
    panel = session['panel']
    name = db.session.query(func.find_name(userid)).all()[0][0] 
    user_role = get_user_role(userid)
    session['user_role'] = user_role
    user_role = session['user_role']
    if 'ptct' in user_role:
        return redirect('/pt_home')
    elif 'ftct' not in user_role:
        return redirect('/po_home')

    data_upcoming = db.session.query(func.ftpt_upcoming(userid)).all()
    upcoming_jobs = []
    for row in data_upcoming:
        new = row[0][1:-1].split(",")
        href = '/ct_booking/' + '/'.join([new[0]] + new[2:] ) + '/' + '0'
        #"/ct_booking/<pn>/<po>/<sd>/<ed>/<d>"
        new.append(href)
        upcoming_jobs.append(dict(zip(('pet_name','name','po_userid', 'start_date', 'end_date','hrefstring'), new)))
    
    return render_template("/12_FT_home.html", name = name,
        upcoming_jobs = upcoming_jobs,
        has_upcoming = (len(upcoming_jobs) > 0),
        panel = panel)

## Page 12b Part time caretaker home page
@view.route("/pt_home",methods=["GET", "POST"])
def render_pt_home():
    
    ## redirects if the person is not logged in
    if 'userid' not in session:
        return redirect('/login')
    
    panel = session['panel']
    userid = session['userid']
    name = db.session.query(func.find_name(userid)).all()[0][0] 

    data_upcoming = db.session.query(func.ftpt_upcoming(userid)).all()
    data_pending = db.session.query(func.ftpt_pending(userid)).all()
    upcoming_jobs = []
    pending_jobs = []
    for row in data_upcoming:
        new = row[0][1:-1].split(",")
        href = '/ct_booking/' + '/'.join([new[0]] + new[2:] ) + '/' + '0'
        #"/ct_booking/<pn>/<po>/<sd>/<ed>/<d>"
        new.append(href)
        upcoming_jobs.append(dict(zip(('pet_name','name','po_userid', 'start_date', 'end_date','hrefstring'), new)))
    
    for row in data_pending:
        new = row[0][1:-1].split(",")
        href = '/ct_booking/' + '/'.join([new[0]] + new[2:] ) + '/' + '0'
        new.append(href)
        pending_jobs.append(dict(zip(('pet_name', 'name','po_userid', 'start_date', 'end_date','hrefstring'), new)))


    return render_template("/12_PT_home.html", name = name,
        upcoming_jobs = upcoming_jobs,
        has_upcoming = (len(upcoming_jobs) > 0),
        pending_jobs = pending_jobs,
        has_pending = (len(pending_jobs) > 0),
        panel = panel)

## Page 13a FT Leave Apply

@view.route("/ft_leave_apply", methods = ["GET", "POST"])
def render_FT_leave_apply():
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    form = AddFT_leave()
    name = db.session.query(func.find_name(userid)).all()[0][0] 
    start_date = form.leave_startdate_field.data
    end_date = form.leave_enddate_field.data
    if form.validate_on_submit():
        db.session.execute(func.ft_applyleave(userid, start_date, end_date))
    search_result = db.session.query(func.ft_upcomingapprovedleave(userid)).all()
    table = []
    for row in search_result:
        d = {}
        new = list(csv.reader([row[0][1:-1]]))[0]
        d["start_date"] = new[0]
        d["end_date"] = new[1]
        href = "/delete_ft_leave/" + userid  +'/'+ '/'.join(row[0][1:-1].split(","))
        d["href"] = href
        table.append(d)
    return render_template("/13_FT_leave.html", table = table, name = name, form = form,panel = panel)

## After delete leave, it will redirect to this page. 

@view.route("/delete_ft_leave/<userid>/<sd>/<ed>", methods = ["GET", "POST"])
def delete_FT_leave(userid, sd, ed):
    db.session.execute(func.ft_cancelleave(userid, sd, ed))
    return redirect('/ft_leave_apply')


## Page 13b Part Time Declare Avail

@view.route("/pt_declare_avail", methods = ["GET", "POST"])
def render_PT_declare_avail():
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    form = AddPT_avail()
    name = db.session.query(func.find_name(userid)).all()[0][0] 
    start_date = form.avail_startdate_field.data
    end_date = form.avail_enddate_field.data
    if form.validate_on_submit():
        db.session.execute(func.pt_applyavail(userid, start_date, end_date))
    search_result = db.session.query(func.pt_upcomingavail(userid)).all()
    table = []
    for row in search_result:
        d = {}
        new = list(csv.reader([row[0][1:-1]]))[0]
        d["start_date"] = new[0]
        d["end_date"] = new[1]
        href = "/delete_pt_avail/" + userid  +'/'+ '/'.join(row[0][1:-1].split(","))
        d["href"] = href
        table.append(d)
    return render_template("/13_PT_avail.html", table = table, name = name, form = form,panel = panel)

## After delete pt avail, it will refresh to the pt avail page

@view.route("/delete_pt_avail/<userid>/<sd>/<ed>", methods = ["GET", "POST"])
def delete_PT_leave(userid, sd, ed):
    db.session.execute(func.pt_del_date(userid, sd, ed))
    return redirect('/pt_declare_avail')


## Page 14 Check Salary

@view.route("/check_salary", methods = ["GET", "POST"])
def render_check_salary():
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session["userid"]
    user_role = get_user_role(userid)
    _MONTH_LOOKUP = {1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June',
        7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'}
    months_active = db.session.query(func.for_gen_buttons(userid)).all()
    table = list()
    for row in months_active:
        mth, yr = row[0].split(',')
        d = {}
        d['firstLetter'] = 'f' if 'ftct' in user_role else 'p'
        d['mth'] = mth
        d['yr'] = yr
        d['full_month'] = _MONTH_LOOKUP[int(mth)]
        table.append(d)
    return render_template("14_salary.html", table = table,panel = panel)



## Page 15a Full time salary breakdown

@view.route("/ftsalary_breakdown/<month>/<year>", methods = ["GET", "POST"])
def render_FTsalary_breakdown(month, year):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    month = int(month)
    _MONTH_LOOKUP = {1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June',
        7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'}
    year = int(year)
    pet_days = db.session.query(func.total_pet_day_mnth(userid, year, month)).all()[0][0]
    total_amt_for_mnth = db.session.query(func.total_trans_pr_mnth(userid, year, month)).all()[0][0]
    trans_this_mth = db.session.query(func.trans_this_month(userid, year, month)).all()
    month  = _MONTH_LOOKUP[month]
    table = list()
    for row in trans_this_mth:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new[0] = db.session.query(func.find_name(new[0])).all()[0][0]
        new[-1] = '{:.02f}'.format(float(new[-1]))
        new[-2] = '{:.02f}'.format(float(new[-2]))
        table.append(dict(zip(('po_name', 'pet_name', 'start_date', 'end_date','rate','trans_amt'), new)))
    avg_trans_amt = total_amt_for_mnth/pet_days
    bonus = max((pet_days - 60)*0.8, 0)
    total_salary = bonus + 3000
    return render_template("/15_FT_salary_breakdown.html", month = month, 
                                                            year = year, 
                                                            pet_days = pet_days, 
                                                            total_amt_for_mnth = '${:.2f}'.format(total_amt_for_mnth), 
                                                            avg_trans_amt = '${:.2f}'.format(avg_trans_amt), 
                                                            bonus = '${:.2f}'.format(bonus, 0), 
                                                            total_salary = '${:.2f}'.format(total_salary), 
                                                            table = table,
                                                            panel = panel)


## Page 15b Part time salary breakdown

@view.route("/ptsalary_breakdown/<month>/<year>", methods = ["GET", "POST"])
def render_PTsalary_breakdown(month, year):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    userid = session['userid']
    month = int(month)
    _MONTH_LOOKUP = {1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June',
        7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'}
    
    year = int(year)
    trans_this_mth = db.session.query(func.trans_this_month(userid, year, month)).all()
    table = list()
    for row in trans_this_mth:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new[0] = db.session.query(func.find_name(new[0])).all()[0][0]
        new[-1] = '{:.02f}'.format(float(new[-1]))
        new[-2] = '{:.02f}'.format(float(new[-2]))
        table.append(dict(zip(('po_name', 'pet_name', 'start_date', 'end_date','rate','trans_amt'), new)))
    total_amt_for_mnth = db.session.query(func.total_trans_pr_mnth(userid, year, month)).all()[0][0]
    total_salary = total_amt_for_mnth*0.75
    month = _MONTH_LOOKUP[month]
    return render_template("/15_PT_salary_breakdown.html", month = month, 
                                                            year = year, 
                                                            total_amt_for_mnth = '${:.2f}'.format(total_amt_for_mnth), 
                                                            total_salary = '${:.2f}'.format(total_salary), 
                                                            table = table,
                                                            panel = panel)

## Page 16 Pet profile page

@view.route("/pet_profile/<po_userid>/<pn>/<d>",methods = ["GET","POST"])
def render_pet_profile(po_userid,pn,d):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    po_name = db.session.query(func.find_name(po_userid)).all()[0][0]    
    pet_type = db.session.query(func.find_pettype(po_userid, pn, d)).all()[0][0]
    spec_req = db.session.query(func.find_specreq(po_userid, pn, d)).all()[0][0]
    birthday = db.session.query(func.find_birthday(po_userid, pn)).all()[0][0]
    return render_template("/16_Pet_profile.html", pet_name = pn, 
                                                    po_name = po_name, 
                                                    pet_type = pet_type,
                                                    birthday = birthday, 
                                                    spec_req = spec_req,
                                                    panel = panel)

## Page 17a Admin home page

@view.route("/admin_home", methods = ["GET", "POST"])
def render_admin_home():
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    mod_form = Admin_modify_price()
    stats_search = Admin_stat_search()


    if 'cat_rate' in request.form: # checking the form
        pairs = [('Cat', mod_form.cat_rate), ('Dog', mod_form.dog_rate), ('Rabbit', mod_form.rabbit_rate), ('Guinea pig', mod_form.guinea_rate),
                ('Hamster', mod_form.hamster_rate), ('Gerbil', mod_form.gerbil_rate), ('Mouse', mod_form.mouse_rate), ('Chinchilla', mod_form.chinchilla_rate)]
        for animal, field in pairs:
            if field.data:
                try:
                    price = float(field.data)
                    if price > 0:                        
                        db.session.execute(func.admin_modify_base(animal, price))
                        db.session.commit()
                except:
                    pass

    animals = ['Cat', 'Dog','Rabbit','Guinea pig','Hamster','Gerbil','Mouse','Chinchilla']
    existingPrices = []
    
    for animal in animals:
        query = "SELECT price FROM pet_type WHERE pet_type = '{}'".format(animal)
        price = db.session.execute(query).fetchone()[0]
        #price = '${:.02f}'.format(db.session.execute(func.find_rate(userid, animal)).fetchone()[0])
        existingPrices.append(price)

    if 'month_field' in request.form: # checking the form
        mth = str(stats_search.month_field.data)
        yr = stats_search.year_field.data
        return redirect('/admin_stats/' + mth + '/' + yr)
    return render_template("17_admin_home.html", mod_form = mod_form, 
                                                    stats_search = stats_search,
                                                    panel = panel,
                                                    **dict(zip((i.replace(' ','_') for i in animals), existingPrices)))

## Page 17b Admin Statistics

@view.route("/admin_stats/<month>/<year>", methods = ["GET", "POST"])
def render_admin_stats(month, year):
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
    month = int(month)
    year = int(year)
    revenue = db.session.query(func.admin_revenue_this_mnth(year, month)).all()[0][0]
    salary = db.session.query(func.admin_salary_payments_this_mnth(year, month)).all()[0][0]
    profit = revenue - salary

    revenue = '${:.02f}'.format(round(revenue, 2))
    salary = '${:.02f}'.format(round(salary, 2))
    profit = '{}${:.02f}'.format('-' if profit < 0 else '', abs(round(profit, 2)))
    salary_bd = db.session.query(func.admin_salary_payments_this_mnth_bd(year, month)).all()
    salary_table = list()
    for row in salary_bd:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new[1] = '${:.02f}'.format(round(float(new[1]), 2))
        salary_table.append(dict(zip(('userid', 'salary2'), new)))

    total_pets = db.session.query(func.admin_total_num_pets(year, month)).all()[0][0]
    pet_bd = db.session.query(func.admin_total_num_pets_bd(year, month)).all()
    bd_pet_table = list()
    for row in pet_bd:
        new = list(csv.reader([row[0][1:-1]]))[0]
        bd_pet_table.append(dict(zip(('pet_type', 'unique_pets'), new)))

    under_perf = db.session.query(func.fire_who(year, month, 3.0, 30)).all() ##TODO Magic numbers
    under_perf_table = list()
    for row in under_perf:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new[2] = '{:.02f}'.format(round(float(new[2]), 2))
        under_perf_table.append(dict(zip(('name', 'userid', 'rating', 'petdays'), new)))

    well_perf = db.session.query(func.praise_who(year, month, 4.2, 60)).all() ##TODO Magic numbers
    well_perf_table = list()
    for row in well_perf:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new[2] = '{:.02f}'.format(round(float(new[2]), 2))
        well_perf_table.append(dict(zip(('name', 'userid', 'rating', 'petdays'), new)))

    val_PO = db.session.query(func.admin_valuable_po(year, month)).all()
    val_PO_table = list()
    for row in val_PO:
        new = list(csv.reader([row[0][1:-1]]))[0]
        new.append(db.session.query(func.find_name(new[0])).all()[0][0])
        new[1] = '${:.02f}'.format(round(float(new[1]), 2))
        val_PO_table.append(dict(zip(('userid','payments', 'name'), new)))

    _MONTH_LOOKUP = {1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June',
        7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'}
    month = _MONTH_LOOKUP[month]
    return render_template("17b_admin_home.html", salary = salary, \
                                                salary_table = salary_table, \
                                                year = year, \
                                                month = month, \
                                                revenue = revenue, \
                                                profit = profit,\
                                                total_pets = total_pets, \
                                                bd_pet_table = bd_pet_table,\
                                                under_perf_table = under_perf_table, \
                                                well_perf_table = well_perf_table, \
                                                val_PO_table = val_PO_table,
                                                panel = panel)


##Page 18 Admin add fulltime employee page
@view.route("/admin/addft", methods = ["GET", "POST"])
def render_addFT():
    if 'userid' not in session:
        return redirect('/login')
    panel = session['panel']
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
            query = "INSERT INTO Caretaker(ct_userid, full_time) VALUES ('{}', TRUE)".format(userid)
            db.session.execute(query)
            db.session.commit()
            if roles:
                roles += '/'
            roles += 'ftct'
        return redirect("/admin_home")
    return render_template("18_addFT.html", form=form,
                                            panel = panel)


##Page ?? Logout page

@view.route('/logout')
def render_logout_page():
    session.pop('userid',None)
    return redirect('/login')

## Additional pages to note
@view.route("/privileged-page", methods=["GET"])
@login_required
def render_privileged_page():
    return "<h1>Hello, {}!</h1>".format(current_user.preferred_name or current_user.userid)

@view.route("/reset",methods = ["GET"])
def render_reset():
    return "<h1>Hello</h1>\
    <h2>Don't forget your userid or password!</h2>"