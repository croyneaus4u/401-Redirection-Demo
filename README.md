# TescoDemo

This Demo demonstrates functionality for 401 Aut Token Refresh.

To See the code, please go to the file named <b>BaseRequestor.swift</b>.

The class implements a basic Queue based mechanism to Cache the Task that have failed Authentication.
Once Authentication is failed, it tries to update the Auth Token from Server and then retry with the Cached Requests.
In the meanwhile all the requests that are made while this Token is being updated, they are addded to the Task Retry cache.

