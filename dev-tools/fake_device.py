#!/usr/bin/env python3
"""
Fake Energy Monitor Device
Simulates an ESP32 device by writing realistic energy readings to Firestore.
Used for testing the Flutter app without physical hardware.
"""

import time
import random
import argparse
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

class FakeEnergyDevice:
    def __init__(self, user_id, device_id, device_name="Fake-Device-001"):
        """Initialize fake energy device."""
        self.user_id = user_id
        self.device_id = device_id
        self.device_name = device_name
        self.db = firestore.client()
        
        # Simulation state
        self.base_power = 300.0  # Base power consumption in Watts
        self.voltage = 230.0
        self.cumulative_energy = 0.0
        self.last_reading_time = time.time()
        
        # Register device
        self._register_device()
    
    def _register_device(self):
        """Register the device in Firestore."""
        device_ref = self.db.collection('users').document(self.user_id)\
                            .collection('devices').document(self.device_id)
        
        device_data = {
            'deviceName': self.device_name,
            'model': 'ESP32-Simulator',
            'registeredAt': SERVER_TIMESTAMP,
            'lastSeen': SERVER_TIMESTAMP,
            'fwVersion': '1.0.0-sim',
            'owner': self.user_id
        }
        
        device_ref.set(device_data)
        print(f"✓ Device registered: {self.device_id}")
    
    def _generate_reading(self):
        """Generate a realistic energy reading."""
        # Add some random variation and daily patterns
        hour = datetime.now().hour
        
        # Simulate daily usage pattern (higher during day, lower at night)
        time_factor = 1.0
        if 6 <= hour <= 9:  # Morning peak
            time_factor = 1.3
        elif 10 <= hour <= 17:  # Day usage
            time_factor = 1.1
        elif 18 <= hour <= 22:  # Evening peak
            time_factor = 1.4
        else:  # Night
            time_factor = 0.6
        
        # Calculate power with random jitter
        power = self.base_power * time_factor + random.uniform(-50, 100)
        power = max(0, power)  # Ensure non-negative
        
        # Voltage fluctuation
        voltage = self.voltage + random.uniform(-3, 3)
        
        # Calculate current
        current = power / voltage if voltage > 0 else 0
        
        # Calculate energy delta (in Wh)
        now = time.time()
        time_delta_hours = (now - self.last_reading_time) / 3600.0
        energy_delta = power * time_delta_hours
        self.cumulative_energy += energy_delta
        self.last_reading_time = now
        
        return {
            'ts': SERVER_TIMESTAMP,
            'power_w': round(power, 2),
            'voltage_v': round(voltage, 2),
            'current_a': round(current, 3),
            'energy_wh': round(self.cumulative_energy, 2),
            'sample_ms': int(time.time() * 1000)
        }
    
    def send_reading(self):
        """Send a reading to Firestore."""
        reading = self._generate_reading()
        
        # Add to readings subcollection
        readings_ref = self.db.collection('users').document(self.user_id)\
                              .collection('devices').document(self.device_id)\
                              .collection('readings')
        
        readings_ref.add(reading)
        
        # Update device last seen
        device_ref = self.db.collection('users').document(self.user_id)\
                            .collection('devices').document(self.device_id)
        device_ref.update({'lastSeen': SERVER_TIMESTAMP})
        
        print(f"📊 Reading sent: {reading['power_w']}W, "
              f"{reading['voltage_v']}V, {reading['current_a']}A, "
              f"Total: {reading['energy_wh']}Wh")
        
        return reading
    
    def run(self, interval=5, count=None):
        """
        Run the fake device, sending readings at specified interval.
        
        Args:
            interval: Seconds between readings (default: 5)
            count: Number of readings to send (None for infinite)
        """
        print(f"\n🚀 Starting fake device: {self.device_name}")
        print(f"   User ID: {self.user_id}")
        print(f"   Device ID: {self.device_id}")
        print(f"   Interval: {interval}s")
        print(f"   Count: {'infinite' if count is None else count}")
        print("\nPress Ctrl+C to stop\n")
        
        readings_sent = 0
        
        try:
            while count is None or readings_sent < count:
                self.send_reading()
                readings_sent += 1
                
                if count is not None:
                    remaining = count - readings_sent
                    print(f"   Remaining: {remaining}")
                
                time.sleep(interval)
        
        except KeyboardInterrupt:
            print(f"\n\n✓ Stopped. Sent {readings_sent} readings.")
        
        print("Goodbye! 👋\n")


def main():
    parser = argparse.ArgumentParser(
        description='Fake Energy Monitor Device - Generates test data for Firestore'
    )
    parser.add_argument(
        '--credentials',
        type=str,
        required=True,
        help='Path to Firebase service account credentials JSON file'
    )
    parser.add_argument(
        '--user-id',
        type=str,
        required=True,
        help='Firebase user ID (owner of the device)'
    )
    parser.add_argument(
        '--device-id',
        type=str,
        default='fake-device-001',
        help='Device ID (default: fake-device-001)'
    )
    parser.add_argument(
        '--device-name',
        type=str,
        default='Fake Energy Monitor',
        help='Device display name (default: Fake Energy Monitor)'
    )
    parser.add_argument(
        '--interval',
        type=int,
        default=5,
        help='Seconds between readings (default: 5)'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=None,
        help='Number of readings to send (default: infinite)'
    )
    
    args = parser.parse_args()
    
    # Initialize Firebase
    print("Initializing Firebase...")
    cred = credentials.Certificate(args.credentials)
    firebase_admin.initialize_app(cred)
    print("✓ Firebase initialized\n")
    
    # Create and run fake device
    device = FakeEnergyDevice(
        user_id=args.user_id,
        device_id=args.device_id,
        device_name=args.device_name
    )
    
    device.run(interval=args.interval, count=args.count)


if __name__ == '__main__':
    main()
