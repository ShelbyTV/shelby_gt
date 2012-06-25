Test Organization / Intent
==========================
Each directory contains a different flavor of tests. Some are self-explanatory, but here's a little color on the distinctions between some of the others.

/requests -- Integration Tests
------------------------------
The intent is to have no stubs, mocks, etc. in integration tests. Integration tests are intended as a straight up test of the api from the perspective of an end user.

The integration tests should be as clean as possible, and they should probably not care about the nitty gritty implementation details of the controllers.

/controllers -- Controller Tests
--------------------------------
Controller tests are intended to test that response codes and messages are being set correctly, that methods are being called the correct number of times, etc.

Future
------
There may be some legacy redundancy between integration and controller tests, but going forward these should ideally be testing unique aspects of the API implementation. 
