from math import floor
from random import randint, random, shuffle, seed
from datetime import date, timedelta
from numpy.random import normal, seed as npseed, choice, geometric

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

_PET_OWNERS = 0.80
_PO_CT_OVERLAP = 0.01

_FULL_TIME = 0.6

_PET_LIST = ['Dog', 'Cat', 'Rabbit', 'Guinea pig', 'Hamster', 'Gerbil', 'Mouse', 'Chinchilla']
_PET_OKAY_PROB = [0.85, 0.85, 0.6, 0.35, 0.3, 0.2, 0.01, 0.2]
_PET_MEAN_PRICE = [80, 80, 75, 60, 50, 50, 40, 70]
_PT_MEAN_OFFSET = 15
_PT_VARIANCE = 20


_START_DATE = date(2020, 9, 1)
_END_DATE = date(2020, 11, 1)
_PT_START_PROB = 0.20
_PT_END_PROB = 0.4
_PT_MAX_RUN = 5
_FT_START_PROB = 0.05
_FT_END_PROB = 0.25
_FT_MAX_RUN = 7

_PET_DISTRI = [0.35, 0.35, 0.1, 0.04, 0.04, 0.01, 0.01, 0.1]
_HAVE_PET_PROB = 0.35
_HAS_PAST_PET_PROB = 0.01
_ADDITIONAL_PET_PROB = 0.2
_PET_BDAY_START_DATE = date(2010, 1, 1)
_PET_BDAY_END_DATE = date(2020, 6, 1)
_PET_ADJ_PROB = 0.25

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
                partTimeAvail[partTimer].append((str(startDay), str(currentDay)))
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


# Output log
if _SHOW_OUTPUT_SUMMARY:
    print()
    printLog()

# Close files
firstUserIn.close()
secondUserIn.close()
