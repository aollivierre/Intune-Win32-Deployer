# from Datto EDR as in here https://rmmvid81500001.infocyte.com/organizations/locations/dbcb05c3-44f8-43ad-8753-e4ae38a1007c navigate to the Org in question
# click Download Agent on top right corner
# click copy command line
# here is an example of it below
# the site specific key is the one that uniquely identifies the site and is mentioned after the --key switch/param which is in this case the 667ui7yht7


# Here is the one for CBA National
agent.windows-amd64.15abaafc56944dcb2d2b9966762eb034d3d46218be7ef8e1321529bdf2df6868.exe --key 667ui7yht7 --url https://rmmvid81500001.infocyte.com

# Here is the one for ICTC
agent.windows-amd64.15abaafc56944dcb2d2b9966762eb034d3d46218be7ef8e1321529bdf2df6868.exe --key sns9fdzrox --url https://rmmvid81500001.infocyte.com


#notice the only difference between the two sites is the value being passed to the key switch/param