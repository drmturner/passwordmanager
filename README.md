# passwordmanager
A secure password manager that encrypts credentials, validates access via Azure group membership, and supports multi-user collaboration through a shared network environment.

i.	Dependency Storage location: Must be set prior to compile
1.	Credentials directory – Holds the entries in the list as json files (one file per record)
2.	encryptionKey.key – holds the binary encryption key used to obfuscate and secure plaintext passwords 
ii.	Functions:
1.	Add Credential
a.	Solution, Use, Username, and Password are required fields
2.	Update Credential
a.	Pulls in current information
b.	Passwords obfuscated in this view
c.	Can update one or more entries per record at a time
3.	Delete Credential
a.	No confirmation required. Make sure you want to delete the record. 
4.	View Password
a.	Passwords are encrypted with PowerShell's ConvertTo-SecureString command using a 128-bit key for speed. 
b.	The passwords are stored in json files in the secure string format so it's unreadable. 
c.	The encryption key is saved as a binary file not a string 
d.	Passwords are obfuscated with 14 asterisks in the table. Doesn’t reflect the actual length of the plaintext password
e.	Plaintext Password is only displayed after successful decryption using the key in the infosec file share
5.	Search for Credential
a.	Search for specific credentials by solution, use, and username. 
b.	Passwords and notes column are not searchable
6.	Allows sorting of Solution, Use, and Username columns
7.	Non-functional & commented out code blocks
a.	Azure connection – Used to validate user running 
iii.	Run from the a file share to ensure that only those with access to that folder can run the script and view the passwords. Even if the exe is moved to the desktop, the network file paths are hardcoded, so a user still needs access to the folder to run it or it will crash. 
iv.	Compiled to exe which can be run from anywhere but pulls credentials and encryption key from the file share folder
