import argparse
import socket


HOST_PORTS = (5555, 5556)


def unavailable_tcp_ports(host: str, ports: tuple[int, ...] = HOST_PORTS, timeout: float = 1.5) -> list[int]:
    if not host or any(char.isspace() for char in host):
        return list(ports)

    unavailable = []
    for port in ports:
        try:
            with socket.create_connection((host, port), timeout=timeout):
                pass
        except (OSError, ValueError):
            unavailable.append(port)
    return unavailable


def require_alohamini_host(host: str, timeout: float = 1.5) -> None:
    unavailable = unavailable_tcp_ports(host, timeout=timeout)
    if unavailable:
        ports = ", ".join(str(port) for port in unavailable)
        raise ConnectionError(
            f"无法连接 {host} 的 Host 端口 {ports}。请确认 Pi IP 正确、PC 与 Pi 在同一网络，"
            "并先启动树莓派 Host。"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Check the configured AlohaMini Host ports.")
    parser.add_argument("host")
    parser.add_argument("--timeout", type=float, default=1.5)
    args = parser.parse_args()
    try:
        require_alohamini_host(args.host, args.timeout)
    except ConnectionError as exc:
        print(f"ERROR: {exc}")
        return 1
    print(f"AlohaMini Host ports are reachable: {args.host}:5555,5556")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
