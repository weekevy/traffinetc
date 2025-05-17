import ipaddress
from typing import List
from concurrent.futures import ThreadPoolExecutor, as_completed
from scapy.all import ARP, Ether, srp, conf

class NetworkScanner:
    def __init__(self, interface: str = "eth0", ip_range: str = "192.168.1.0/24", timeout: int = 2, threads: int = 100):
        self.interface = interface
        self.ip_range = ip_range
        self.timeout = timeout
        self.threads = threads

    def single_scan(self, ip: str) -> str:
        conf.verb = 0 ; arp = ARP(pdst=ip)  ; ether = Ether(dst="ff:ff:ff:ff:ff:ff") ; packet = ether / arp
        try:
            answered, _ = srp(packet, iface=self.interface, timeout=self.timeout)
            for _, rcv in answered:
                return rcv.psrc
        except Exception:
            return None

    def scan(self) -> List[str]:
        try: network = ipaddress.IPv4Network(self.ip_range, strict=False)
        except ValueError: raise ValueError(f"Invalid IP range: {self.ip_range}")
        ip_list = [str(ip) for ip in network.hosts()]
        discovered = []
        with ThreadPoolExecutor(max_workers=self.threads) as executor:
            futures = {executor.submit(self.single_scan, ip): ip for ip in ip_list}
            for future in as_completed(futures):
                result = future.result()
                if result:
                    discovered.append(result)
        return discovered

    

if __name__  == "__main__":
    