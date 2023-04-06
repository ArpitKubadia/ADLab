# Terraform variables
# See 'variables.tf' for definitions

# Required
resource-group       = "AD_EH_CTF"
ip-whitelist         = ["1.2.3.4/32", "8.8.8.0/24","128.220.0.0/16"]

# Optional (defaults are shown)
timezone             = "Eastern Standard Time"
domain-name-label    = "eh-ctf"
domain-dns-name      = "th.local"
windows-user         = "cooten"
linux-user           = "cooten"
hackbox-hostname     = "hackbox"
dc-hostname          = "dc"
winserv2019-hostname = "winserv2019"
win10-hostname       = "win10"
win10-size           = "Standard_B1ms"
winserv2019-size     = "Standard_B1ms"
dc-size              = "Standard_B1ms"
hackbox-size         = "Standard_B1ms"
