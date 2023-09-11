#!/bin/bash
# DESC: This script controls out-of-office replies based on calendar entries.
# It searches for all-day events named by the variable EVENT_NAME for the next day in all mailboxes of the domain.
# Define the name of the event to search for
EVENT_NAME="OOO"
# Define the mail domain to search for
MAILDOM="acme.com"
# Define the regex filter to select the mailboxes to search for
MAILBOX_TO_SEARCH='^team....@'
# If such an event is found, it sets the out-of-office reply for that mailbox.
# If the event has a description, it uses that as the out-of-office message, otherwise it uses a default message.
# USAGE: Run this script without any arguments. It requires zmprov and zmmailbox utilities to be available in the PATH.
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#/bin/bash

# Set locale to English
unset LC_ALL
export LC_ALL=en_US.UTF-8
export LANG=en_US

# Default out-of-office message
OOO_MSG="Dear Sir or Madam,

Thank you for your message!

The recipient of this mailbox is absent.
In urgent cases please contact our helpdesk:
eMail: elvira@acme.com"


# GET ALL MAILBOXES FOR DOMAIN                        FILTER ALIASES ONLY     EXTRACT MAIL     FILTER ACCOUNTS WITH REGEX
# Get all mailboxes for the domain, filter aliases only, extract mail, filter accounts with regex
zmprov sa -v zimbraMailDeliveryAddress="*@$MAILDOM" | grep zimbraMailAlias  | sed 's/.*: //' | egrep "$MAILBOX_TO_SEARCH"          | while read mb
do
  echo "---------- $mb"  # SEARCH FOR TOMORROW ALL DAY EVENTS                            SELECT EVENTS WITH NAME "OOO"
  # Search for tomorrow all day events, select events with name "OOO"
  read OOO < <(zmmailbox -v -z -m $mb getAppointmentSummaries +1day +1day | jq -r '.[] | select(.name=="'$EVENT_NAME'") .name + ":" + .fragment')
  # If an "OOO" event is found
  if [ $(echo "$OOO" | cut -d: -f1 | wc -c) -gt 5 ]
  then
    echo "INFO: Found OOO event"
    # If the "OOO" event has a description
    if [ $(echo "$OOO" | cut -d: -f2 | wc -c) -gt 5 ]
    then
      echo "INFO: Found custom OOO message"
      OOO_MSG="$(echo $OOO | cut -d: -f2 | sed 's#\. #.\n#g' )"
    else
      echo "INFO: Found no OOO message, use default one"
    fi
    echo "WARNING: Configure OOO for USER $mb"
    # Set the out-of-office reply for the mailbox
    zmprov ma $mb zimbraPrefOutOfOfficeReply "$OOO_MSG"
    zmprov ma $mb zimbraPrefOutOfOfficeReplyEnabled TRUE
    # Set the start date for the out-of-office reply
    zmprov ma $mb zimbraPrefOutOfOfficeFromDate $(date "+%Y%m%d000000Z")
    # Set the end date for the out-of-office reply
    zmprov ma $mb zimbraPrefOutOfOfficeUntilDate $(date -d "+1 day" "+%Y%m%d215959Z")
  else
    echo "INFO: Found no OOO event"
  fi
done
