#!/bin/bash

# $1 is a csv file with user data (with no headings) of the form:
# 9912345,firstname,lastname
#
# $2 is the uidNumber to start incrementing from.
#  If emtpy, use yy000 where yy is the current two-digit year

add_user_to_ldif() {
  studentnum=$1
  firstname=$2
  lastname=$3
  uidnum=$4
  filename=$5

# for ldif format see
# https://help.ubuntu.com/lts/serverguide/openldap-server.html#openldap-server-populate

  echo -e "dn: uid=$studentnum,ou=Users,dc=hackerspace,dc=tbl\n\
objectClass: inetOrgPerson\n\
objectClass: posixAccount\n\
objectClass: shadowAccount\n\
uid: $studentnum\n\
sn: $lastname\n\
givenName: $firstname\n\
cn: "$firstname $lastname"\n\
displayName: "$firstname $lastname"\n\
uidNumber: $uidnum\n\
gidNumber: 5000\n\
userPassword: wolf\n\
gecos: "$firstname $lastname"\n\
loginShell: /bin/bash\n\
homeDirectory: /home/$studentnum\n\
" >> $filename

}

# Recursive function that finds the next available uidNumber, given starting value
next_available_uid() {
  uidNumber=$1

  # check if the uidNumber already in use
  USERINFO=$(getent passwd $uidNumber)

  # if no user found, the result will be an empty
  if [ "$USERINFO" ]; then
      # Already taken, increment and try again, recursive
      uidNumber=$((uidNumber+1))
      echo -e $( next_available_uid "$uidNumber" )
  else
      echo -e "$uidNumber"
  fi
}


# MAIN 

echo -e "\nReading $1:"

# if no uid parameter provided set start uid to yy000, yy = two digit current year
if [ $2 ]; then
  uidNumber="$2"
else
  uidNumber="$(date +'%y')000"
fi
echo -e "Starting uidNumber = $uidNumber\n"

# set lower uid limit
UID_LOWER_LIMIT=1000
if [ $uidNumber -lt $UID_LOWER_LIMIT ]; then
  echo -e "** Please choose a starting uidNumber >= 1000 **"
  exit
fi

# clear the output ldif file:
ldiffile="$1.ldif"
echo -e "" > "$ldiffile"

# count new users
num_new_users=0

OLDIFS=$IFS
IFS=","

# read the csv file line by line
while read username_raw firstname_raw lastname_raw
  do
    echo "$username_raw $firstname_raw $lastname_raw"
    # remove whitespace
    # this is garbage!  SHould do this in a function, probabyl much cleanr way to do it...but it's working.
    username=$(echo "${username_raw}" | awk '{gsub(/^ +| +$/,"")} {print $0}')
    firstname=$(echo "${firstname_raw}" | awk '{gsub(/^ +| +$/,"")} {print $0}')
    lastname=$(echo "${lastname_raw}" | awk '{gsub(/^ +| +$/,"")} {print $0}')

    echo "$username $firstname $lastname"
    echo "succes...?"

    # check if the username (student number) already exists as a user
    id $username
    # if user found, exit code 0 from id command
    if [ "$?" = "0" ]; then
	echo -e "$username already exists, skipped.\n"
    else
	uidNumber=$( next_available_uid "$uidNumber" )
	echo -e "$username new, adding with uid=$uidNumber\n"
	add_user_to_ldif "$username" "$firstname" "$lastname" "$uidNumber" "$ldiffile"
        uidNumber=$((uidNumber+1))
	num_new_users=$((num_new_users+1))
    fi

 done < $1
IFS=$OLDIFS

if [ "$num_new_users" = "0" ]; then
  echo -e "No new users found\n"
else
  echo -e "$num_new_users new users found. LDIF file created. To add users"
  ldapadd -x -D cn=admin,dc=hackerspace,dc=tbl -W -f $ldiffile
fi
