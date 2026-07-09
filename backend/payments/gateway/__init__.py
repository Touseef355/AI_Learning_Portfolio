from django.conf import settings

def get_payment_gateway():
    """
    Factory function — returns the active payment gateway.
    To switch to Simpaisa: set PAYMENT_GATEWAY = 'simpaisa' in settings.py
    Default is 'mock' for development/testing.
    """
    gateway = getattr(settings, 'PAYMENT_GATEWAY', 'mock')

    if gateway == 'simpaisa':
        from .simpaisa import SimpaisaGateway
        return SimpaisaGateway()
    else:
        from .mock_gateway import MockGateway
        return MockGateway()
