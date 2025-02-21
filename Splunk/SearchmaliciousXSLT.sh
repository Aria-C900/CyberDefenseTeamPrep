# splunk search for CVE-2023-46214 
# Created 2025

# "In Splunk Enterprise versions below 9.0.7 and 9.1.2, Splunk Enterprise does not safely #sanitize extensible stylesheet language transformations (XSLT) that users supply. 
# This means #that an attacker can upload malicious XSLT which can result in remote code execution on the #Splunk Enterprise instance.
# The code explaination was generated using ChatGPT.


splunk search "'splunkd_ui' ((uri=\"*NO_BINARY_CHECK=1*\" AND \"*input.path=*.xsl*\") OR uri=\"*dispatch*.xsl*\") AND uri!= \"*splunkd_ui*\"
| rex field=uri \"(?<string>=\\s*([\\S\\s]+))\" 
| eval decoded_field=urldecode(string) 
| eval action=case(match(status,\"200\"),\"Allowed\",match(status,\"303|500|401|403|404|301|406\"),\"Blocked\",1=1,\"Unknown\") 
| stats count min(_time) as firstTime max(_time) as lastTime by clientip useragent uri decoded_field action host 
| rename clientip as src, uri as dest_uri 
| iplocation src 
| fillnull value=\"N/A\" 
| security_content_ctime(firstTime) 
| security_content_ctime(lastTime) 
| table firstTime, lastTime src, useragent, action, count, Country, Region, City, dest_uri, decoded_field 
| splunk_rce_via_user_xslt_filter'" -maxout 0 -output rawdata > splunkmaliciousXSLT.txt


#line 8 
# starts the search with the command "splunk search" and filters for uris in "NO_BINARY_CHECK=1", "*input.path=*.xsl" and #  # excludes events with "splunkd_ui" to avoid palse positives

#line 9
# The rex command extracts a portion of the uri field (everything after an equals sign) into a new field called string.
# The extracted string is then URL-decoded using urldecode, resulting in decoded_field.

#line 10 - 11
# An eval statement uses the HTTP status code (status) to classify the request:
# A status of 200 is labeled as "Allowed".
# Status codes like 303, 500, 401, 403, 404, 301, or 406 are marked as "Blocked".
# Any other status is tagged as "Unknown".

#line 12 - 14
# The stats command aggregates events by key fields (client IP, user agent, URI, decoded_field, action, and host) while also calculating the count
# The fields are then renamed (e.g., clientip becomes src and uri becomes dest_uri) for clarity.
# The iplocation command enriches the data by adding geographical information (Country, Region, City) based on the source IP.

#line 15 - 18
# fillnull replaces any missing values with "N/A".
# security_content_ctime converts the epoch times (firstTime and lastTime) into human-readable format.
# Finally, the table command formats the output to display key fields like first and last seen times, source IP, user agent, # action taken, count of events, location data, destination URI, and the decoded field.

#line 19
# The overall Splunk search is executed with no result limit (-maxout 0), and the raw output is saved to a file named splunkmaliciousXSLT.txt.
