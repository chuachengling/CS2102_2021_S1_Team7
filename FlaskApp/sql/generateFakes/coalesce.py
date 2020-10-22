from math import floor
from random import randint, shuffle, seed
seed(2102)

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
_OVERLAP = 0.01

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
    if email in emailData:
        continue
    personalData.append((name, postal, address, hp, email))
for line in secondPersonalDataIn:
    name, postal, address, hp, email = line.strip().split(',')
    hp = str(randint(8, 9)) + hp
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

# Write all user/password data
with open('processed/Accounts.txt', 'w') as accountsOut:
    accountsOut.write('INSERT INTO Accounts (userid, password, deactivate) VALUES\n')
    accountsOut.write(',\n'.join('({},{},FALSE)'.format(*pair) for pair in adminUsers))
    accountsOut.write(',')
    accountsOut.write(',\n'.join('({},{},FALSE)'.format(*pair) for pair in activatedUsers))
    accountsOut.write(',')
    accountsOut.write(',\n'.join('({},{},TRUE)'.format(*pair) for pair in deactivatedUsers))
    accountsOut.write(';\n')
    verbosePrint('\'processed/Accounts.txt\' written!')

writeLog('\t> {} admin users'.format(len(adminUsers)))
writeLog('\t> {} normal users'.format(len(normalUsers)))
writeLog('\t\t> {} activated users'.format(len(activatedUsers)))
writeLog('\t\t> {} deactivated users'.format(len(deactivatedUsers)))

# Write all personal data
with open('processed/Users.txt', 'w') as usersOut:
    usersOut.write('INSERT INTO Users (userid, name, postal, address, hp, email) VALUES\n')
    usersOut.write(',\n'.join('({},{})'.format(account[0], ','.join(pair)) for account, pair in zip(normalUsers, personalData)))
    usersOut.write(';\n')
    verbosePrint('\'processed/Users.txt\' written!')

# Write admin data
with open('processed/Admin.txt', 'w') as adminOut:
    adminOut.write('INSERT INTO Admin (userid) VALUES\n')
    adminOut.write(',\n'.join('({})'.format(account[0]) for account in adminUsers))
    usersOut.write(';\n')
    verbosePrint('\'processed/Admin.txt\' written!')

# Output log
if _SHOW_OUTPUT_SUMMARY:
    print()
    printLog()

# Close files
firstUserIn.close()
secondUserIn.close()
