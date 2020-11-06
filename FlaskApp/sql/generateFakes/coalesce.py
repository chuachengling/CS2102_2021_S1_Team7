from math import floor
from random import randint, random, shuffle, seed
from datetime import date, datetime, timedelta
from numpy.random import normal, seed as npseed, choice, geometric, binomial

seed(2102)
npseed(2102)

_SHOW_VERBOSE = True
_SHOW_OUTPUT_SUMMARY = True

# Verbose print
def verbosePrint(message):
    if _SHOW_VERBOSE:
        print('* {}'.format(message))

# Log variables
log = []

def writeLog(message):
    log.append(message)

def printLog():
    print('\n'.join(log))

# Constants
_NORMAL_USERS = 0.995
_ACTIVATED_USERS = 0.98

_PET_OWNERS = 0.75
_PO_CT_OVERLAP = 0.01

_FULL_TIME = 0.2

_PET_LIST = ['Dog', 'Cat', 'Rabbit', 'Guinea pig', 'Hamster', 'Gerbil', 'Mouse', 'Chinchilla']
_PET_OKAY_PROB = [0.85, 0.85, 0.6, 0.35, 0.3, 0.2, 0.01, 0.2]
_PET_MEAN_PRICE = [80, 80, 75, 60, 50, 50, 40, 70]
_PT_MEAN_OFFSET = 15
_PT_VARIANCE = 20


_START_DATE = date(2020, 9, 1)
_END_DATE = date(2020, 11, 1)
_TOTAL_MONTHS = 2
_PT_START_PROB = 0.20
_PT_END_PROB = 0.4
_PT_MAX_RUN = 5
_FT_START_PROB = 0.01
_FT_END_PROB = 0.25
_FT_MAX_RUN = 7

_PET_DISTRI = [0.35, 0.35, 0.1, 0.04, 0.04, 0.01, 0.01, 0.1]
_HAVE_PET_PROB = 0.35
_HAS_PAST_PET_PROB = 0.01
_ADDITIONAL_PET_PROB = 0.2
_PET_BDAY_START_DATE = date(2010, 1, 1)
_PET_BDAY_END_DATE = date(2020, 6, 1)
_PET_ADJ_PROB = 0.25

_TODAY_DATE = date(2020, 9, 28)
_PT_BOOK_PROB = 0.9
_FT_BOOK_PROB = 0.5
_FT_LOAD_FACTOR = 15
_REVIEW_PROB = 0.7

_ACCEPTED_PROB = 0.5
_PAYMENT_PROB = 0.5
_FT_REVIEW_BOUNDS = (3, 5)
_PT_REVIEW_BOUNDS = (2, 4)

_CHAT_N = 4
_CHAT_P = 0.25
_CHAT_BACKTRACK_DAYS = 4

# Open files
firstUserIn = open('raw/usernames.csv', 'r')
secondUserIn = open('raw/usernames2.csv', 'r')
firstPersonalDataIn = open('raw/personalData.csv', 'r')
secondPersonalDataIn = open('raw/personalData2.csv', 'r')

# Intermediate files
userData = {}
personalData = []
emailData = set()

# Read userid/password data
for line in firstUserIn:
    userid, password = line.strip().split(',')
    if userid in userData:
        continue
    userData[userid] = password
for line in secondUserIn:
    userid, password = line.strip().split(',')
    if userid in userData:
        continue
    userData[userid] = password

numUsers = len(userData)
writeLog('> {} unique users'.format(numUsers))

# Read personal data
for line in firstPersonalDataIn:
    name, postal, address, hp, email = line.strip().split(',')
    hp = str(randint(8, 9)) + hp
    name = name.replace('\'', '')
    if email in emailData:
        continue
    personalData.append((name, postal, address, hp, email))
for line in secondPersonalDataIn:
    name, postal, address, hp, email = line.strip().split(',')
    hp = str(randint(8, 9)) + hp
    name = name.replace('\'', '')
    if email in emailData:
        continue
    personalData.append((name, postal, address, hp, email))
shuffle(personalData)

numPersonalData = len(personalData)
numNormalUsers = floor(_NORMAL_USERS * numUsers)
numActivatedUsers = floor(_ACTIVATED_USERS * numNormalUsers)
allUsers = list(userData.items())
normalUsers = allUsers[:numNormalUsers]
adminUsers = allUsers[numNormalUsers:]
activatedUsers = normalUsers[:numActivatedUsers]
deactivatedUsers = normalUsers[numActivatedUsers:]
shuffle(normalUsers)


# Write all user/password data
with open('processed/Accounts.txt', 'w') as accountsOut:
    accountsOut.write('INSERT INTO Accounts (userid, password, deactivate) VALUES\n')
    accountsOut.write(',\n'.join('(\'{}\',\'{}\',FALSE)'.format(*pair) for pair in adminUsers))
    accountsOut.write(',')
    accountsOut.write(',\n'.join('(\'{}\',\'{}\',FALSE)'.format(*pair) for pair in activatedUsers))
    accountsOut.write(',')
    accountsOut.write(',\n'.join('(\'{}\',\'{}\',TRUE)'.format(*pair) for pair in deactivatedUsers))
    accountsOut.write(';\n')
    verbosePrint('\'processed/Accounts.txt\' written!')

writeLog('\t> {} admin users'.format(len(adminUsers)))
writeLog('\t> {} normal users'.format(len(normalUsers)))
writeLog('\t\t> {} activated users'.format(len(activatedUsers)))
writeLog('\t\t> {} deactivated users\n'.format(len(deactivatedUsers)))

# Write all personal data
with open('processed/Users.txt', 'w') as usersOut:
    usersOut.write('INSERT INTO Users (userid, name, postal, address, hp, email) VALUES\n')
    usersOut.write(',\n'.join('(\'{}\',\'{}\')'.format(account[0], '\',\''.join(pair)) for account, pair in zip(normalUsers, personalData)))
    usersOut.write(';\n')
    verbosePrint('\'processed/Users.txt\' written!')

# Write admin data
with open('processed/Admin.txt', 'w') as adminOut:
    adminOut.write('INSERT INTO Admin (userid) VALUES\n')
    adminOut.write(',\n'.join('(\'{}\')'.format(account[0]) for account in adminUsers))
    adminOut.write(';\n')
    verbosePrint('\'processed/Admin.txt\' written!')

numPetOwners = floor(numNormalUsers * (_PET_OWNERS - _PO_CT_OVERLAP))
numCareTakers = floor(numNormalUsers * (1 - _PET_OWNERS - _PO_CT_OVERLAP))
numOverlap = numNormalUsers - numPetOwners - numCareTakers
petOwners = [account[0] for account in normalUsers[:numPetOwners+numOverlap]]
careTakers = [account[0] for account in normalUsers[numPetOwners:]]

shuffle(careTakers)
numFulltime = floor((numCareTakers + numOverlap) * _FULL_TIME)
fullTimers = careTakers[:numFulltime]
partTimers = careTakers[numFulltime:]

writeLog('> {} pet owners'.format(numPetOwners + numOverlap))
writeLog('> {} care takers'.format(numCareTakers + numOverlap))
writeLog('\t> {} full timers'.format(numFulltime))
writeLog('\t> {} part timers'.format(numCareTakers + numOverlap - numFulltime))
writeLog('> {} overlapped roles\n'.format(numOverlap))

# Write pet owner data
with open('processed/Pet_Owner.txt', 'w') as petOwnerOut:
    petOwnerOut.write('INSERT INTO Pet_Owner (po_userid, credit) VALUES\n')
    petOwnerOut.write(',\n'.join('(\'{}\',\'{}\')'.format(account, randint(1000000000000000, 9999999999999999)) for account in petOwners))
    petOwnerOut.write(';\n')
    verbosePrint('\'processed/Pet_Owner.txt\' written!')

# Write care taker data
with open('processed/Caretaker.txt', 'w') as caretakerOut:
    caretakerOut.write('INSERT INTO Caretaker (ct_userid, bank_acc, full_time) VALUES\n')
    caretakerOut.write(',\n'.join('(\'{}\', \'{}\', TRUE)'.format(account, randint(1000000000, 9999999999)) for account in fullTimers))
    caretakerOut.write(',\n')
    caretakerOut.write(',\n'.join('(\'{}\', \'{}\', FALSE)'.format(account, randint(1000000000, 9999999999)) for account in partTimers))
    caretakerOut.write(';\n')
    verbosePrint('\'processed/Caretaker.txt\' written!')

writeLog('> {} pet types'.format(len(_PET_LIST)))

# Write pet type data
with open('processed/Pet_Type.txt', 'w') as petTypeOut:
    petTypeOut.write('INSERT INTO Pet_Type (pet_type, price) VALUES\n')
    petTypeOut.write(',\n'.join('(\'{}\', {})'.format(pet, round(50 + random()*20, 2)) for pet in _PET_LIST))
    petTypeOut.write(';\n')
    verbosePrint('\'processed/Pet_Type.txt\' written!')

partTimePetOkay = {}
for petName, petProb, petMean in zip(_PET_LIST, _PET_OKAY_PROB, _PET_MEAN_PRICE):
    partTimePetOkay[petName] = {}
    for partTimer in partTimers:
        if random() < petProb:
            partTimePetOkay[petName][partTimer] = max(normal(petMean + _PT_MEAN_OFFSET, _PT_VARIANCE), petMean)

# Write part-timer's pet handling data
with open('processed/PT_validpet.txt', 'w') as ptPetOkayOut:
    ptPetOkayOut.write('INSERT INTO PT_validpet (ct_userid, pet_type, price) VALUES\n')
    ptPetOkayOut.write(',\n'.join('(\'{}\', \'{}\', {})'.format(userid, petname, price) for petname in partTimePetOkay for userid, price in partTimePetOkay[petname].items()))
    ptPetOkayOut.write(';\n')
    verbosePrint('\'processed/PT_validpet.txt\' written!')

fullTimePetOkay = {}
for petName, petProb in zip(_PET_LIST, _PET_OKAY_PROB):
    fullTimePetOkay[petName] = []
    for fullTimer in fullTimers:
        if random() < petProb:
            fullTimePetOkay[petName].append(fullTimer)

# Write full-timer's pet handling data
with open('processed/FT_validpet.txt', 'w') as ftPetOkayOut:
    ftPetOkayOut.write('INSERT INTO FT_validpet (ct_userid, pet_type) VALUES\n')
    ftPetOkayOut.write(',\n'.join('(\'{}\', \'{}\')'.format(userid, petname) for petname in fullTimePetOkay for userid in fullTimePetOkay[petname]))
    ftPetOkayOut.write(';\n')
    verbosePrint('\'processed/FT_validpet.txt\' written!')

petAdjPool = []
# Read pet adjective pool
with open('raw/petAdjectives.txt', 'r') as adjIn:
    for line in adjIn:
        if not line.strip():
            break
        petAdjPool.append(line.strip())

petNamePool = list(set((i[0][:-1] + 'ty') for i in personalData if len(i[0]) > 1))
totalAlivePets = 0
totalPets = 0
pets = {}
for petOwner in petOwners:
    pets[petOwner] = []
    numOfPets = geometric(1 - _HAVE_PET_PROB) + 1
    totalAlivePets += numOfPets
    petNames = choice(petNamePool, numOfPets, replace = False)
    for petNo in range(numOfPets):
        petsToGen = 1
        if random() < _HAS_PAST_PET_PROB:
            petsToGen += geometric(1 - _ADDITIONAL_PET_PROB)
        totalPets += petsToGen
        for deadNo in range(petsToGen):
            birthday = _PET_BDAY_START_DATE + timedelta(days = randint(0, (_PET_BDAY_END_DATE - _PET_BDAY_START_DATE).days))
            specReq = ', '.join(choice(petAdjPool, geometric(1 - _PET_ADJ_PROB), replace = False))
            petType = choice(_PET_LIST, p = _PET_DISTRI)
            pets[petOwner].append((petNames[petNo], deadNo, str(birthday), specReq, petType))

# Write full-timer's pet handling data
with open('processed/Pet.txt', 'w') as petOut:
    petOut.write('INSERT INTO Pet (po_userid, pet_name, dead, birthday, spec_req, pet_type) VALUES\n')
    petOut.write(',\n'.join('(\'{}\', \'{}\', {}, \'{}\', \'{}\', \'{}\')'.format(petowner, *vals) for petowner in pets for vals in pets[petowner]))
    petOut.write(';\n')
    verbosePrint('\'processed/Pet.txt\' written!')

writeLog('> {} total pets (Average pets owned: {:.2f})'.format(totalPets, totalPets/len(petOwners)))
writeLog('\t> {} active pets'.format(totalAlivePets))
writeLog('\t> {} inactive pets\n'.format(totalPets - totalAlivePets))

partTimeTotalDays = 0
partTimeAvail = {}
for partTimer in partTimers:
    partTimeAvail[partTimer] = []
    isWorking = False
    startDay = None
    totalDays = (_END_DATE - _START_DATE).days
    for dayDelta in range(totalDays):
        currentDay = _START_DATE + timedelta(days = dayDelta)
        if not isWorking:
            if random() < _PT_START_PROB:
                isWorking = True
                startDay = currentDay
        if isWorking:
            if (currentDay - startDay).days == _PT_MAX_RUN or random() < _PT_END_PROB or dayDelta == totalDays-1:
                partTimeAvail[partTimer].append((startDay, currentDay))
                partTimeTotalDays += (currentDay - startDay).days + 1
                isWorking = False

writeLog('> Average part-timer coverage: {:.2f}%'.format(100*partTimeTotalDays/(len(partTimers)*(totalDays+1))))

# Write part time availability data
with open('processed/PT_Availability.txt', 'w') as ptAvailOut:
    ptAvailOut.write('INSERT INTO PT_Availability (ct_userid, avail_sd, avail_ed) VALUES\n')
    ptAvailOut.write(',\n'.join('(\'{}\', \'{}\', \'{}\')'.format(ptUser, *date) for ptUser in partTimeAvail for date in partTimeAvail[ptUser]))
    ptAvailOut.write(';\n')
    verbosePrint('\'processed/PT_Availability.txt\' written!')

fullTimeTotalDays = 0
fullTimeLeave = {}
for fullTimer in fullTimers:
    fullTimeLeave[fullTimer] = []
    isLeave = False
    startDay = None
    totalDays = (_END_DATE - _START_DATE).days
    for dayDelta in range(totalDays):
        currentDay = _START_DATE + timedelta(days = dayDelta)
        if not isLeave:
            if random() < _FT_START_PROB:
                isLeave = True
                startDay = currentDay
        if isLeave:
            if (currentDay - startDay).days == _FT_MAX_RUN or random() < _FT_END_PROB or dayDelta == totalDays-1:
                fullTimeLeave[fullTimer].append((startDay, currentDay))
                fullTimeTotalDays += (currentDay - startDay).days + 1
                isLeave = False

writeLog('> Average full-timer coverage: {:.2f}%\n'.format(100 - 100*fullTimeTotalDays/(len(fullTimers)*(totalDays+1))))

# Write full time availability data
with open('processed/FT_Leave.txt', 'w') as ftLeaveOut:
    ftLeaveOut.write('INSERT INTO FT_Leave (ct_userid, leave_sd, leave_ed) VALUES\n')
    ftLeaveOut.write(',\n'.join('(\'{}\', \'{}\', \'{}\')'.format(ftUser, *date) for ftUser in fullTimeLeave for date in fullTimeLeave[ftUser]))
    ftLeaveOut.write(';\n')
    verbosePrint('\'processed/FT_Leave.txt\' written!')

allPets = {i: [] for i in _PET_LIST}
for petOwner in pets:
    for pet in pets[petOwner]:
        allPets[pet[4]].append((petOwner, pet[0], pet[1]))

fullTimeAvail = {}
for fullTimer in fullTimeLeave:
    curBusy = [(None, _START_DATE - timedelta(days = 1))] + fullTimeLeave[fullTimer] + [(_END_DATE + timedelta(days = 1), None)]
    fullTimeAvail[fullTimer] = []
    for i in range(len(curBusy) - 1):
        if (curBusy[i+1][0] - curBusy[i][1]).days > 1:
            fullTimeAvail[fullTimer].append((curBusy[i][1] + timedelta(days = 1), curBusy[i+1][0] - timedelta(days = 1)))

petAvailability = set()
rejectedSet = []

fullTimeAvailability = {}
fullTimeBusyDays = 0
fullTimeJobs = []
for fullTimer in fullTimeAvail:
    okayPets = [i for i in fullTimePetOkay if fullTimer in fullTimePetOkay[i]]
    if not okayPets:
        continue
    for availabilityRange in fullTimeAvail[fullTimer]:
        bookings = binomial(_FT_LOAD_FACTOR, _FT_BOOK_PROB)
        dateRange = ((availabilityRange[0] - _START_DATE).days, (availabilityRange[1] - _START_DATE).days)
        for _ in range(bookings):
            choiceFlag = True
            rollPet = choice(okayPets)
            rollExact = allPets[rollPet][randint(0, len(allPets[rollPet])-1)]
            rollStart = randint(*dateRange)
            rollEnd = randint(*dateRange)
            if rollStart > rollEnd:
                rollStart, rollEnd = rollEnd, rollStart
            if rollEnd - rollStart > _FT_MAX_RUN:
                rollEnd = rollStart + _FT_MAX_RUN
            for i in range(rollStart, rollEnd+1):
                if (i, rollExact) in petAvailability or ((i, fullTimer) in fullTimeAvailability and fullTimeAvailability[(i, fullTimer)] == 5) or rollExact[0] == fullTimer:
                    if rollExact[0] != fullTimer:
                        rejectedSet.append((rollPet, *rollExact, fullTimer, _START_DATE + timedelta(days = rollStart), _START_DATE + timedelta(days = rollEnd)))
                    choiceFlag = False
            if not choiceFlag:
                continue
            for i in range(rollStart, rollEnd+1):
                petAvailability.add((i, rollExact))
                fullTimeAvailability[(i, fullTimer)] = fullTimeAvailability.get((i, fullTimer), 0) + 1
            fullTimeBusyDays += rollEnd - rollStart + 1
            fullTimeJobs.append((rollPet, *rollExact, fullTimer, _START_DATE + timedelta(days = rollStart), _START_DATE + timedelta(days = rollEnd)))

partTimeAvailability = {}
partTimeBusyDays = 0
partTimeJobs = []
for partTimer in partTimeAvail:
    okayPets = [i for i in partTimePetOkay if partTimer in partTimePetOkay[i]]
    if not okayPets:
        continue
    for availabilityRange in partTimeAvail[partTimer]:
        bookings = min(geometric(_PT_BOOK_PROB) + 1, 5)
        dateRange = ((availabilityRange[0] - _START_DATE).days, (availabilityRange[1] - _START_DATE).days)
        for _ in range(bookings):
            choiceFlag = True
            while choiceFlag:
                choiceFlag = False
                rollPet = choice(okayPets)
                rollExact = allPets[rollPet][randint(0, len(allPets[rollPet])-1)]
                rollStart = randint(*dateRange)
                rollEnd = randint(*dateRange)
                if rollStart > rollEnd:
                    rollStart, rollEnd = rollEnd, rollStart
                if rollEnd - rollStart > _PT_MAX_RUN:
                    rollEnd = rollStart + _PT_MAX_RUN
                for i in range(rollStart, rollEnd+1):
                    if (i, rollExact) in petAvailability or ((i, partTimer) in partTimeAvailability and partTimeAvailability[(i, partTimer)] == 5) or rollExact[0] == partTimer:
                        if rollExact[0] != partTimer:
                            rejectedSet.append((rollPet, *rollExact, partTimer, _START_DATE + timedelta(days = rollStart), _START_DATE + timedelta(days = rollEnd)))
                        choiceFlag = True
            for i in range(rollStart, rollEnd+1):
                petAvailability.add((i, rollExact))
                partTimeAvailability[(i, partTimer)] = partTimeAvailability.get((i, partTimer), 0) + 1
            partTimeBusyDays += rollEnd - rollStart + 1
            partTimeJobs.append((rollPet, *rollExact, partTimer, _START_DATE + timedelta(days = rollStart), _START_DATE + timedelta(days = rollEnd)))

sampleMessages = []
with open('raw/sampleMessages.txt', 'r') as sampleIn:
    for line in sampleIn:
        if not line.strip() or '\'' in line:
            continue
        sampleMessages.append(line.strip())
def generateMessages():
    return choice(sampleMessages, size = binomial(_CHAT_N, _CHAT_P), replace = False)
isFirstChat = False
totalChatMessages = 0

pastKeys = set()
with open('processed/Looking_After.txt', 'w') as lookingOut, open('processed/Chat.txt', 'w') as chatOut:
    lookingOut.write('INSERT INTO Looking_After (po_userid, pet_name, dead, ct_userid, start_date, end_date, status, trans_pr, payment_op, rating, review) VALUES\n')
    chatOut.write('INSERT INTO Chat (po_userid, pet_name, dead, ct_userid, start_date, end_date, time, sender, text) VALUES\n')
    for i, job in enumerate(partTimeJobs):
        pet_type, _, _, _, _, start_date, end_date = job
        if start_date < _TODAY_DATE:
            if end_date < _TODAY_DATE:
                status = 'Completed'
            else:
                status = 'Accepted'
        else:
            if random() < _ACCEPTED_PROB:
                status = 'Accepted'
            else:
                status = 'Pending'
        trans_pr = max(normal(_PET_MEAN_PRICE[_PET_LIST.index(pet_type)], _PT_VARIANCE), min(_PET_MEAN_PRICE))
        payment_op = 'Credit Card' if random() < _PAYMENT_PROB else 'Cash'
        if status == 'Completed' and random() < _REVIEW_PROB:
            rating = '\'' + str(randint(*_PT_REVIEW_BOUNDS)) + '\''
            review = '\'' + choice(sampleMessages) + '\''
        else:
            rating = 'NULL'
            review = 'NULL'

        if job in pastKeys:
            continue
        pastKeys.add(job)
        if i != 0:
            lookingOut.write(',\n')
        lookingOut.write('({}, \'{}\', {}, \'{}\', {}, {})'.format(', '.join('\'{}\''.format(i) for i in job[1:]), status, trans_pr, payment_op, rating, review))
        messages = generateMessages()
        totalChatMessages += len(messages)
        for message in messages:
            standard = min(_TODAY_DATE, start_date)
            standard = datetime(standard.year, standard.month, standard.day)
            standard -= timedelta(days = randint(0, _CHAT_BACKTRACK_DAYS), hours = randint(0, 23), minutes = randint(0, 59), seconds = randint(0, 59))
            if not isFirstChat:
                isFirstChat = True
            else:
                chatOut.write(',\n');
            chatOut.write('({}, \'{}\', {}, \'{}\')'.format(', '.join('\'{}\''.format(i) for i in job[1:]), standard.strftime('%Y-%m-%d %H:%M:%S'), randint(1, 2), message));
        
    for i, job in enumerate(fullTimeJobs):
        pet_type, _, _, _, _, start_date, end_date = job
        if start_date < _TODAY_DATE:
            if end_date < _TODAY_DATE:
                status = 'Completed'
            else:
                status = 'Accepted'
        else:
            status = 'Accepted'
        trans_pr = max(normal(_PET_MEAN_PRICE[_PET_LIST.index(pet_type)], _PT_VARIANCE), min(_PET_MEAN_PRICE))
        payment_op = 'Credit Card' if random() < _PAYMENT_PROB else 'Cash'
        if status == 'Completed' and random() < _REVIEW_PROB:
            rating = '\'' + str(randint(*_FT_REVIEW_BOUNDS)) + '\''
            review = '\'' + choice(sampleMessages) + '\''
        else:
            rating = 'NULL'
            review = 'NULL'

        if job in pastKeys:
            continue
        pastKeys.add(job)
        if i != 0 or len(partTimeJobs) > 0:
            lookingOut.write(',\n')
        lookingOut.write('({}, \'{}\', {}, \'{}\', {}, {})'.format(', '.join('\'{}\''.format(i) for i in job[1:]), status, trans_pr, payment_op, rating, review))
        messages = generateMessages()
        totalChatMessages += len(messages)
        for message in messages:
            standard = min(_TODAY_DATE, start_date)
            standard = datetime(standard.year, standard.month, standard.day)
            standard -= timedelta(days = randint(0, _CHAT_BACKTRACK_DAYS), hours = randint(0, 23), minutes = randint(0, 59), seconds = randint(0, 59))
            if not isFirstChat:
                isFirstChat = True
            else:
                chatOut.write(',\n');
            chatOut.write('({}, \'{}\', {}, \'{}\')'.format(', '.join('\'{}\''.format(i) for i in job[1:]), standard.strftime('%Y-%m-%d %H:%M:%S'), randint(1, 2), message));
        
    
    for i, job in enumerate(rejectedSet):
        pet_type = job[0]
        status = 'Rejected'
        trans_pr = max(normal(_PET_MEAN_PRICE[_PET_LIST.index(pet_type)], _PT_VARIANCE), min(_PET_MEAN_PRICE))
        payment_op = 'Credit Card' if random() < _PAYMENT_PROB else 'Cash'
        if status == 'Completed' and random() < _REVIEW_PROB:
            rating = '\'' + str(randint(*_PT_REVIEW_BOUNDS)) + '\''
            review = '\'' + choice(sampleMessages) + '\''
        else:
            rating = 'NULL'
            review = 'NULL'

        if job in pastKeys:
            continue
        pastKeys.add(job)
        if i != 0 or len(partTimeJobs) + len(fullTimeJobs) > 0:
            lookingOut.write(',\n')
        lookingOut.write('({}, \'{}\', {}, \'{}\', {}, {})'.format(', '.join('\'{}\''.format(i) for i in job[1:]), status, trans_pr, payment_op, rating, review))
        messages = generateMessages()
        totalChatMessages += len(messages)
        for message in messages:
            standard = min(_TODAY_DATE, start_date)
            standard = datetime(standard.year, standard.month, standard.day)
            standard -= timedelta(days = randint(0, _CHAT_BACKTRACK_DAYS), hours = randint(0, 23), minutes = randint(0, 59), seconds = randint(0, 59))
            if not isFirstChat:
                isFirstChat = True
            else:
                chatOut.write(',\n');
            chatOut.write('({}, \'{}\', {}, \'{}\')'.format(', '.join('\'{}\''.format(i) for i in job[1:]), standard.strftime('%Y-%m-%d %H:%M:%S'), randint(1, 2), message));

    lookingOut.write(';\n')
    chatOut.write(';\n');
    verbosePrint('\'processed/Looking_After.txt\' written!')
    verbosePrint('\'processed/Chat.txt\' written!')

writeLog('> Rejected transactions: {}'.format(len(rejectedSet)))
writeLog('> Total transactions: {}'.format(len(partTimeJobs) + len(fullTimeJobs)))
writeLog('\t> Total part-time transactions: {}'.format(len(partTimeJobs)))
writeLog('\t> Total full-time transactions: {}'.format(len(fullTimeJobs)))
writeLog('> Average part-timer pet days per month: {:.2f}'.format(partTimeBusyDays/len(partTimers)/_TOTAL_MONTHS))
writeLog('> Average full-timer pet days per month: {:.2f}\n'.format(fullTimeBusyDays/len(fullTimers)/_TOTAL_MONTHS))    

# Output log
if _SHOW_OUTPUT_SUMMARY:
    print()
    printLog()

# Close files
firstUserIn.close()
secondUserIn.close()
