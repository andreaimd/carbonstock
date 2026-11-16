#Create a Global Forest Watch Data API key.
#Section 1: Sign up. Then set the password with the link in the email.
#Section 2: Get the token and the key. The key is shown on the screen only.
#The script does not save it in any file. It should be added to .Renviron as GFW_KEY.
##############################################################################

##LIBRARIES
rm(list = ls())
pacman::p_load(httr, rstudioapi)


##PATH
base <- "https://data-api.globalforestwatch.org"


#1 Sign up: run it once----
nm <- readline("Name: ")
em <- readline("Email: ")

r <- POST(paste0(base, "/auth/sign-up"),
          body = list(name = nm, email = em),
          encode = "json")
print(status_code(r))
print(content(r))
rm(nm, em, r)

#Now open the email, check the spam folder, and set the password with the link


#2 Token and key----
em <- readline("Email of your account: ")
pw <- rstudioapi::askForPassword("Password of your Global Forest Watch account")

#Token, the username is the email
r <- POST(paste0(base, "/auth/token"),
          body = list(username = em, password = pw),
          encode = "form")
print(status_code(r))
tok <- content(r)$data$access_token
rm(pw)

#API key
r <- POST(paste0(base, "/auth/apikey"),
          add_headers(Authorization = paste("Bearer", tok)),
          body = list(alias = "ANY_NAME", email = em, organization = readline("Organization: ")),
          encode = "json")
print(status_code(r))
print(content(r))
rm(em, tok, r)

#The key is the value called api_key. Copy it and add this line to the file that opens
#GFW_KEY=your_key_here
file.edit("~/.Renviron")
