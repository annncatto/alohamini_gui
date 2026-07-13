import unittest
from unittest import mock

from alohamini_ops.app.network import require_alohamini_host, unavailable_tcp_ports


class HostPortCheckTest(unittest.TestCase):
    def test_reports_unavailable_port(self):
        self.assertEqual(unavailable_tcp_ports("127.0.0.1", (1,), timeout=0.05), [1])

    def test_accepts_reachable_port(self):
        with mock.patch("alohamini_ops.app.network.socket.create_connection") as connect:
            self.assertEqual(unavailable_tcp_ports("robot.local", (5555,), timeout=0.2), [])
        connect.assert_called_once_with(("robot.local", 5555), timeout=0.2)

    def test_rejects_empty_host(self):
        with self.assertRaises(ConnectionError):
            require_alohamini_host("")


if __name__ == "__main__":
    unittest.main()
