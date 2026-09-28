# DHCPTool

DHCP Tool

This program is to address the fact that when you set a DHCP reservation on a Windows DHCP server it doesn't replicate to the Failover Partner Server unless you do it manually, and when you replicate the scope manually the entire set of reservations from the source server are sent to the destination server and any reservation that was not on the source server will be deleted from the destination server.

There are a few files involved. 
Changelog.txt this is the text for the "About" button.

oui\_trimmed.csv this csv file has the OUI of the MAC address to manufacture names 

"Set DHCP ReservationXXX\_Template.ps1" (where XXX is the version number) This is the heart of the program.

Build-DHCP\_Tool.ps1 This script is used to make your EXE it has a variable for the workspace or folder with all of your files.

I run ISE as my domain admin account and open and then run Build-DHCP\_Tool.ps1 It checks for the highest numbered "Set DHCP ReservationXXX\_Template.ps1" file that is in the workspace folder. It also copies the OUI data and changelog.txt data.

