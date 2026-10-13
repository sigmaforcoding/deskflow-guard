import importlib.util
from pathlib import Path
import unittest

script = Path(__file__).resolve().parents[1] / 'Sources' / 'guard.py'
spec = importlib.util.spec_from_file_location('guard', script)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class ConnectionClassificationTests(unittest.TestCase):
    def test_timeout_allows_next_server(self):
        self.assertFalse(guard.should_stop('WARNING: failed to connect to server=Timed out, trying next server in list'))

    def test_unreachable_host_allows_next_server(self):
        self.assertFalse(guard.should_stop('WARNING: failed to connect to server=cannot connect socket: Host is down, trying next server in list'))

    def test_exhausted_addresses_stop(self):
        self.assertTrue(guard.should_stop('WARNING: failed to connect to server: Timed out'))

    def test_lost_server_stops(self):
        self.assertTrue(guard.should_stop('INFO: server is dead'))

    def test_mouse_transition_keeps_connection(self):
        self.assertFalse(guard.should_stop('INFO: leaving computer'))


class ClientSelectionTests(unittest.TestCase):
    def test_only_exact_client_path_is_stopped(self):
        from unittest.mock import patch
        import subprocess
        rows = '\n'.join([
            '101 ' + guard.CORE + ' client',
            '102 ' + guard.CORE + ' server',
            '103 /bin/sh -c ' + guard.CORE + ' client',
            '104 /different/deskflow-core client',
        ])
        result = subprocess.CompletedProcess([], 0, rows)
        with patch.object(guard.subprocess, 'run', return_value=result), patch.object(guard.os, 'kill') as kill, patch('builtins.print'):
            guard.stop_client()
            kill.assert_called_once_with(101, guard.signal.SIGKILL)

    def test_failed_process_inventory_never_signals(self):
        from unittest.mock import patch
        import subprocess
        result = subprocess.CompletedProcess([], 1, '')
        with patch.object(guard.subprocess, 'run', return_value=result), patch.object(guard.os, 'kill') as kill:
            guard.stop_client()
            kill.assert_not_called()

if __name__ == '__main__':
    unittest.main()
