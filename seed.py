import random
import string
import uuid
from datetime import date, timedelta

from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.certificates.models import Certificate
from apps.clients.models import Client
from apps.devices.models import Device
from apps.logs.models import Log
from apps.otp.models import UserOtp
from apps.requests.models import Request
from apps.tokens.models import Token
from apps.users.models import User, UserRole, UserStatus


def rand_str(n=8):
    return ''.join(random.choices(string.ascii_lowercase, k=n))


def rand_digits(n):
    return ''.join(random.choices(string.digits, k=n))


def rand_phone():
    return f'+998{rand_digits(9)}'


UZBEK_CITIES = [
    'Toshkent', 'Samarqand', 'Namangan', 'Andijon', 'Fargona',
    'Buxoro', 'Nukus', 'Qarshi', 'Jizzax', 'Termiz',
]

BRANCHES = [
    'Asosiy filial', 'Yunusobod filial', 'Chilonzor filial',
    'Mirzo Ulugbek filial', 'Sergeli filial', 'Olmazor filial',
    'Bektemir filial', 'Shayxontohur filial', 'Yakkasaroy filial',
    'Uchtepa filial',
]

ORGANISATIONS = [
    'Kapital Bank', 'Ipoteka Bank', 'Hamkorbank', 'Uzpromstroybank',
    'Agrobank', 'Asaka Bank', 'Davr Bank', 'Ziraat Bank',
    'NBU', 'Aloqabank',
]

DEVICE_MODELS = [
    'Samsung Galaxy S21', 'iPhone 13', 'Xiaomi Mi 11',
    'Huawei P40', 'OnePlus 9', 'Google Pixel 6',
    'Realme GT', 'OPPO Find X3', 'Vivo X60', 'Asus ZenFone 8',
]

OS_VERSIONS = ['10.0', '11.0', '12.0', '13.0', '14.0', '15.0']

LOG_ACTIONS = [
    'login', 'logout', 'create_client', 'update_client', 'delete_client',
    'issue_certificate', 'revoke_certificate', 'create_request',
    'approve_request', 'reject_request', 'assign_token', 'detach_token',
    'change_password', 'reset_password', 'view_report',
]

ISSUERS = [
    'CN=UzDST CA, O=Uzinfocom, C=UZ',
    'CN=E-IMZO CA, O=UZINFOCOM, C=UZ',
    'CN=Kapital Bank CA, O=Kapital Bank, C=UZ',
    'CN=IPOteka CA, O=Ipoteka Bank, C=UZ',
]


class Command(BaseCommand):
    help = 'Seed database with 100 rows per table'

    def handle(self, *args, **options):
        self.stdout.write('Seeding started...')

        users = self._seed_users()
        clients = self._seed_clients(users)
        devices = self._seed_devices(clients)
        requests = self._seed_requests(clients, devices, users)
        self._seed_certificates(requests, clients, users)
        self._seed_tokens(users)
        self._seed_logs(users)
        self._seed_otps()

        self.stdout.write(self.style.SUCCESS('Seeding completed successfully.'))

    # ------------------------------------------------------------------
    def _seed_users(self):
        self.stdout.write('  Creating 100 users...')
        roles = [UserRole.ADMIN, UserRole.LIMITED_ADMIN, UserRole.USER, UserRole.OPERATOR]
        hashed = make_password('Test1234!')
        users = []
        for i in range(1, 101):
            username = f'user_{i}_{rand_str(4)}'
            u = User(
                username=username,
                first_name=f'First{i}',
                last_name=f'Last{i}',
                email=f'{username}@example.com',
                password=hashed,
                role=random.choice(roles),
                branch=random.choice(BRANCHES),
                ibank=random.choice([True, False]),
                mbank=random.choice([True, False]),
                iabs=random.choice([True, False]),
                parent_id=0,
                count=random.randint(1, 5),
                status=random.choice([UserStatus.ACTIVE, UserStatus.INACTIVE]),
                mfo=rand_digits(5),
                token_count=random.randint(0, 20),
                verified_token_count=random.randint(0, 10),
                failed_login_attempts=0,
            )
            users.append(u)
        User.objects.bulk_create(users, ignore_conflicts=True)
        created = list(User.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} users in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_clients(self, users):
        self.stdout.write('  Creating 100 clients...')
        cert_types = [Client.CertificateType.IABS_USER, Client.CertificateType.BANK_CLIENT]
        hashed = make_password('ClientPass1!')
        clients = []
        for i in range(100):
            branch_user = random.choice(users)
            operator = random.choice(users)
            c = Client(
                cname=f'Client {i + 1} {rand_str(4)}',
                sname=f'ShortName{i + 1}',
                location=random.choice(UZBEK_CITIES),
                state=random.choice(UZBEK_CITIES),
                country='UZB',
                address=f'{rand_digits(3)} ko\'cha, {i + 1}-uy',
                email=f'client{i + 1}_{rand_str(4)}@example.com',
                organisation=random.choice(ORGANISATIONS),
                org_unit=f'Dept-{random.randint(1, 20)}',
                status=random.choice([Client.Status.ACTIVE, Client.Status.INACTIVE]),
                inn=rand_digits(9) if random.random() > 0.3 else None,
                pinfl=rand_digits(14) if random.random() > 0.3 else None,
                phone=rand_phone(),
                password=hashed,
                fix=random.choice([True, False]),
                comment=f'Izoh {i + 1}',
                operator=operator,
                branch_user=branch_user,
                fido_user_id=random.randint(1000, 99999),
                fido_user_type_id=random.randint(1, 5),
                login=f'login_{rand_str(6)}',
            )
            clients.append(c)
        Client.objects.bulk_create(clients)
        created = list(Client.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} clients in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_devices(self, clients):
        self.stdout.write('  Creating 100 devices...')
        d_types = list(Device.DeviceType.values)
        d_platforms = list(Device.DevicePlatform.values)
        d_id_types = list(Device.DeviceIdType.values)
        devices = []
        for i in range(100):
            dev = Device(
                user=random.choice(clients),
                type=random.choice(d_types),
                platform=random.choice(d_platforms),
                device_id_type=random.choice(d_id_types),
                device_id_number=str(uuid.uuid4()),
                is_primary=random.choice([True, False]),
                status=random.choice([Device.DeviceStatus.ACTIVE, Device.DeviceStatus.INACTIVE]),
                os_version=random.choice(OS_VERSIONS),
                model=random.choice(DEVICE_MODELS),
                firebase_token=rand_str(32),
            )
            devices.append(dev)
        Device.objects.bulk_create(devices)
        created = list(Device.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} devices in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_requests(self, clients, devices, users):
        self.stdout.write('  Creating 100 requests...')
        reqs = []
        for i in range(100):
            client = random.choice(clients)
            device = random.choice(devices)
            branch_user = random.choice(users)
            operator = random.choice(users)
            r = Request(
                request=f'REQUEST_BODY_{rand_str(16).upper()}',
                container=random.choice(['PKCS12', 'PEM', 'DER', None]),
                type=random.randint(1, 4),
                file_name=f'cert_{rand_str(6)}.p12',
                password=rand_str(12),
                cng=random.choice([0, 1, None]),
                status=random.randint(0, 3),
                user=client,
                device=device,
                operator=operator,
                branch_user=branch_user,
            )
            reqs.append(r)
        Request.objects.bulk_create(reqs)
        created = list(Request.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} requests in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_certificates(self, requests, clients, users):
        self.stdout.write('  Creating 100 certificates...')
        statuses = list(Certificate.Status.values)
        rev_statuses = list(Certificate.RevokedStatus.values)
        today = date.today()
        certs = []
        for i in range(100):
            req = random.choice(requests)
            client = random.choice(clients)
            branch_user = random.choice(users)
            operator = random.choice(users)
            cert_from = today - timedelta(days=random.randint(30, 365))
            cert_to = cert_from + timedelta(days=365)
            status = random.choice(statuses)
            c = Certificate(
                issuer=random.choice(ISSUERS),
                cert_sn=rand_str(4).upper() + rand_digits(12),
                cert_thumb=rand_str(8).upper() + rand_digits(8),
                cert_from=cert_from,
                cert_to=cert_to,
                base64='MIIBkTCB+wIJ...' + rand_str(64),
                pfx='MIIJ...' + rand_str(32) if random.random() > 0.5 else None,
                status=status,
                rev_reason='Eskirgan' if status == Certificate.Status.REVOKED else None,
                branch_rev_status=random.choice(rev_statuses),
                file_name=f'cert_{rand_str(6)}.p12',
                request=req,
                user=client,
                operator=operator,
                branch_user=branch_user,
                sync=random.randint(0, 1),
                last_login=timezone.now().strftime('%Y-%m-%d %H:%M:%S') if random.random() > 0.4 else None,
                revoke_date=timezone.now() - timedelta(days=random.randint(1, 90)) if status == Certificate.Status.REVOKED else None,
            )
            certs.append(c)
        Certificate.objects.bulk_create(certs)
        created = list(Certificate.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} certificates in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_tokens(self, users):
        self.stdout.write('  Creating 100 hardware tokens...')
        tokens = []
        for i in range(100):
            branch_user = random.choice(users)
            is_attached = random.choice([True, False])
            t = Token(
                seria_number=f'SN-{rand_digits(4)}-{rand_str(6).upper()}',
                is_used=random.randint(0, 50),
                branch_user=branch_user,
                is_attached=is_attached,
                attached_at=timezone.now() - timedelta(days=random.randint(1, 300)) if is_attached else None,
            )
            tokens.append(t)
        Token.objects.bulk_create(tokens)
        created = list(Token.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} tokens in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_logs(self, users):
        self.stdout.write('  Creating 100 logs...')
        ips = [f'192.168.{random.randint(1, 10)}.{random.randint(1, 254)}' for _ in range(20)]
        logs = []
        for i in range(100):
            actor = random.choice(users)
            action = random.choice(LOG_ACTIONS)
            lg = Log(
                actor=actor,
                username=actor.username,
                action=action,
                comment=f'{action} amaliyoti bajarildi',
                context={'detail': f'item_id={random.randint(1, 500)}', 'status': random.choice(['ok', 'fail'])},
                ip_address=random.choice(ips),
            )
            logs.append(lg)
        Log.objects.bulk_create(logs)
        created = list(Log.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} logs in DB')
        return created

    # ------------------------------------------------------------------
    def _seed_otps(self):
        self.stdout.write('  Creating 100 OTPs...')
        otps = []
        for i in range(100):
            use_inn = random.random() > 0.5
            otp = UserOtp(
                otp=rand_digits(5),
                inn=rand_digits(9) if use_inn else None,
                pinfl=rand_digits(14) if not use_inn else None,
                phone=rand_phone(),
            )
            otps.append(otp)
        UserOtp.objects.bulk_create(otps)
        created = list(UserOtp.objects.order_by('-id')[:100])
        self.stdout.write(f'    -> {len(created)} OTPs in DB')
        return created
