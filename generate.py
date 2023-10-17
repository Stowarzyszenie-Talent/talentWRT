#!/usr/bin/env python3

import os
import string
from abc import ABC, abstractmethod
from typing import Generic, TextIO, TypeVar
from dataclasses import dataclass, field
from pathlib import Path
import re
import shlex
import argparse

LUCI_APP_TALENT = Path("./luci-app-talent/luci-app-talent.ipk")

parser = argparse.ArgumentParser()
parser.add_argument("output", type=argparse.FileType('w'))
ns = parser.parse_args()

os.chdir(Path(__file__).parent)

def check_ipv4(input: str) -> bool:
	match = re.match("^(\\d+)\\.(\\d+)\\.(\\d+)\\.(\\d+)$", input)
	if match is None:
		return False

	def check_octet(octet):
		try:
			if int(octet, 10) > 255:
				return False
		except ValueError:
			return False
		return True

	if not all(check_octet(group) for group in match.groups()[1:]):
		return False

	return True

CT = TypeVar("CT", covariant=True)
T = TypeVar("T")

class QueryType(Generic[CT], ABC):
	@abstractmethod
	def hint(self, default: CT | None) -> str: pass
	@abstractmethod
	def parse(self, input: str) -> CT: pass

@dataclass
class OneOf(QueryType[str]):
	values: list[str]
	case_sensitive: bool = field(default=False, kw_only=True)

	def __post_init__(self):
		if not self.case_sensitive:
			self.lower_values = { value.lower(): value for value in self.values }

	def hint(self, default: str | None) -> str:
		return "{" + ", ".join(f"[{v}]" if v == default else v  for v in self.values) + "}"

	def parse(self, input: str) -> str:
		if self.case_sensitive:
			if input not in self.values:
				raise ValueError("invalid value")
			return input
		else:
			lower = input.lower()
			if lower not in self.lower_values:
				raise ValueError("invalid value")
			return self.lower_values[lower]

# "safe"
class UciSafeString(QueryType[str]):
	def hint(self, default: str | None) -> str: return f"[{default}]" if default else ""
	def parse(self, input: str) -> str:
		if "'" in input or "\\" in input:
			raise ValueError("don't")
		return input

class File(QueryType[TextIO]):
	def hint(self, default: TextIO | None) -> str: return f"(path) [{default}]" if default else ""
	def parse(self, input: str) -> TextIO:
		try:
			return Path(input).open('r')
		except Exception as ex:
			raise ValueError(f"Could not open file: {ex}")

@dataclass
class IPv4Address(QueryType[str]):
	def hint(self, default: str | None) -> str: return f"(adres IPv4){f' [{default}]' if default else ''}"
	def parse(self, input: str) -> str:
		if not check_ipv4(input):
			raise ValueError("nieprawidłowy adres IP")
		return input

class WiFiPassword(QueryType[str | None]):
	def hint(self, _) -> str:
		return "(przynajmniej 8 znaków lub nic (otwarta sieć))"
	def parse(self, input: str) -> str | None:
		if input == "":
			return None
		elif len(input) < 8:
			raise ValueError("Password too short")
		return input

class Integer(QueryType[int]):
	def hint(self, default: int | None) -> str: return f"(int){f' [{default}]' if default else ''}"
	def parse(self, input: str) -> int: return int(input, 10)

def error(msg: str):
	print(f"\x1b[31;1merror\x1b[0m: {msg}")

def query(name: str, type: QueryType[T], /, *, default: T | None = None) -> T:
	prompt = name
	hint = type.hint(default)
	if hint != "": prompt += f" {hint}"
	prompt += ": "

	while True:
		value = input(prompt).strip()
		if value == "" and default is not None: return default
		try:
			return type.parse(value)
		except ValueError as ve:
			error(str(ve))

def substitute(file: str, values: dict[str, str] = {}) -> str:
	return Path(file).read_text().format_map(values)

if not LUCI_APP_TALENT.exists():
	error(f"{LUCI_APP_TALENT} does not exist")

kind = query("Typ routera", OneOf(["ST", "LO3"]))
hostname: str
numer_st: int | None = None

if kind == "ST":
	numer_st = query('Numer STka', Integer())
	hostname = f"ST{numer_st}"
else:
	while True:
		hostname = query("Nazwa", UciSafeString())
		if hostname == "":
			error("Nazwa routera nie może być pusta")
		else: break

channelwidth24 = query("Szerokość pasma 2.4GHz", OneOf(["HT20", "HT40"]), default="HT20")
channelwidth5 = query("Szerokość pasma 5GHz", OneOf(["HT20", "HT40", "VHT80"]), default="HT40")

uci_config = ""

uci_config += substitute("./uci-templates/system", {"HOSTNAME": hostname })

uci_config += substitute("./uci-templates/wifi", {
	"SSID": hostname,
	"PASMO24": channelwidth24,
	"PASMO5": channelwidth5
})

if kind == "LO3":
	password = query("Hasło sieci Wi-Fi", WiFiPassword())

	if password is None:
		uci_config += substitute("./uci-templates/wifi_nopass")
	else:
		uci_config += substitute("./uci-templates/wifi_withpass", {
			"PASSWORD": password 
		})

if kind == "LO3":
	with query("Ścieżka do pliku z kluczem talent", File()) as f:
		uci_config += substitute("./uci-templates/lo3", {
			"WANIP": query("IP WAN", IPv4Address()),
			"WANMASK": query("Maska WAN", IPv4Address(), default="255.255.255.0"),
			"WANGATEWAY": query("Gateway WAN", IPv4Address(), default="10.1.22.254"),
			"TALENTKEY": shlex.quote(f.read().strip())
		})

	i = 0
	while True:
		addr = query("IP routera talent", IPv4Address(), default="")
		if addr == "": break
		name = query(f"Nazwa dla {addr}", UciSafeString(), default="")
		uci_config += f"set talent.router{i}=router\n"
		uci_config += f"set talent.router{i}.name='{name}'\n"
		uci_config += f"set talent.router{i}.ipaddr='{addr}'\n"
		i += 1
else:
	assert numer_st is not None
	uci_config += substitute("./uci-templates/st", { "NUMER": str(numer_st) })

uci_config += "commit"

# NOTE: This cannot be a drop-in replacement for shlex.quote because *some*
#       shells store strings as a null-terminated sequence of characters
#       and this means that any null bytes in a $'' literal would mess up
#       the value as read by the shell.
def quote_for_echo(value: bytes) -> str:
	out = "'"
	allowed = {ord(chr) for chr in string.printable if chr not in {'\\', "\'", '\n'}}
	for byte in value:
		if byte in allowed: out += chr(byte)
		elif byte == 0: out += "\\0"
		else: out += f"\\x{hex(byte)[2:]:>02}"
	out += "'"
	return out

@dataclass
class Raw: value: str

print(f"Writing script to {ns.output.name}")
output: TextIO = ns.output

output.write("set -euo pipefail\n")

if kind == "LO3":
	output.write(f"echo -en {quote_for_echo(LUCI_APP_TALENT.read_bytes())} >/tmp/luci-app-talent.ipk\n")
	output.write("opkg update\n")
	output.write("opkg install /tmp/luci-app-talent.ipk\n")
	output.write("rm /tmp/luci-app-talent.ipk\n")

output.write(f"echo -n {shlex.quote(uci_config)} | uci batch\n")
