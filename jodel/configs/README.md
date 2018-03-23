This dir contains a config for each city you will harvest. Each config sources
a corresponding account-data file that was generated once.

Each config file (with name <cityname>-config.sh) should contain lines as in
the following example:


source accounts/Kbh-account-data.sh

num\_of\_recent\_posts\_to\_harvest=50
seconds\_between\_each\_harvest=60

