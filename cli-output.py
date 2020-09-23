import pyfiglet
from pyfiglet import Figlet

import colorama
from colorama import Fore, Style

from lolpython import lol_py

def log_launch(message):
  print(f'🚀 {Style.BRIGHT}{message}{Style.RESET_ALL}')

def log_info(message):
  print(f'ℹ️  {Style.BRIGHT}{message}{Style.RESET_ALL}')

def horizontal_rule():
    print(f'{Style.BRIGHT}{Fore.BLUE}―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――{Style.RESET_ALL}')

def upper_rule():
    print(f'{Style.BRIGHT}{Fore.BLUE}▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔{Style.RESET_ALL}')

def lower_rule():
    print(f'{Style.BRIGHT}{Fore.BLUE}▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁{Style.RESET_ALL}')

def log_check(message):
  print(f' {Style.BRIGHT}{Fore.GREEN}\N{HEAVY CHECK MARK} {Style.RESET_ALL}{message}')

def log_error(message):
  print(f'❌ {Style.BRIGHT}{Fore.RED}{message}{Style.RESET_ALL}')

def log_link(prefix="",url=""):
  print(f'   🌎 {Style.BRIGHT}{Fore.WHITE}{prefix} {Fore.CYAN}{url}{Style.RESET_ALL}')

def log_blank(message):
  print(f'   {message}')

def log_blank_bright(message):
  print(f'   {Style.BRIGHT}{message}{Style.RESET_ALL}')

f = Figlet(font='Cybermedium', width=100)
text = f.renderText('Codefresh Pipeline')

lower_rule()
lol_py(text,end="")
upper_rule()

log_launch("Lorem ipsum dolor bacon sit amet")
log_check("Bacon sit lorem amet")
log_check("Amet bacon sit dolor")
log_link("Web URL:","https://www.foo.bar/path/to/repo")
log_link("Git URL:","ssh+git@src.foo.bar/path/to/repo.git")
log_check("Amet bacon sit dolor")
horizontal_rule()

log_info("Lorem ipsum dolor bacon sit amet")
log_blank_bright("codefresh-pipelines repo. You can visit in a browser by navigating to:")
log_link("Web URL:","https://www.foo.bar/path/to/repo")
log_check("Bacon sit lorem amet")
log_check("Amet bacon sit dolor")
log_error("Must provide lorem ipsum dolor env var")
horizontal_rule()