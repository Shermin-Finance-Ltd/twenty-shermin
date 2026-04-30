#!/usr/bin/env bash
# Configure the Shermin CRM data model on a freshly deployed Twenty workspace.
# Idempotent — re-running on an already-configured workspace is safe; existing
# objects/fields/roles are detected and skipped.
#
# What this does:
#   1. Renames Company -> Retailer, Person -> Contact (label only, apiName preserved).
#   2. Creates a `staffMember` custom object with 19 fields covering personal
#      details, employment, compensation, holiday, contract.
#   3. Adds two SELECT fields to Retailer for the two-pipeline kanban model:
#      `prospectingStage` (BDM-owned: Prospect, Engaged, On Hold, Dead, Converted)
#      `onboardingStage`  (Sales Support-owned: File Collection ... Live, Dead)
#   4. Creates an "HR Admin" role and denies the Member role any access to
#      the staffMember object — Staff is visible only to Admin + HR Admin.
#
# Prerequisites:
#   TWENTY_BASE   URL of the workspace (default: v0 ALB)
#   TWENTY_API_KEY  Workspace API key with admin scope. Generate at
#                   Settings -> API & Webhooks -> Create API Key.
#
# Things this script DOESN'T do (configure via Twenty UI):
#   - Default Kanban views per role.
#   - The conversion workflow (prospectingStage = Converted -> set
#     onboardingStage = File Collection). Twenty's workflow API requires
#     workflowVersion management beyond what's worth scripting at v0.
#   - Logo upload (drag and drop in Settings -> General).
#   - Assigning the HR Admin role to specific users (Settings -> Members).

set -euo pipefail

TWENTY_BASE="${TWENTY_BASE:-https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com}"
: "${TWENTY_API_KEY:?TWENTY_API_KEY is required}"

CURL=(curl --silent --insecure --show-error -H "Authorization: Bearer $TWENTY_API_KEY" -H "Content-Type: application/json")

# ----- helpers -----------------------------------------------------------------

# Get an object metadata by nameSingular. Returns the full object JSON, or empty.
object_by_name() {
  local name="$1"
  "${CURL[@]}" "$TWENTY_BASE/rest/metadata/objects" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
objs = d.get('data', {}).get('objects', []) if isinstance(d, dict) else []
for o in objs:
    if o.get('nameSingular') == '$name':
        print(json.dumps(o)); sys.exit(0)
" || true
}

# Patch object label.
rename_object() {
  local id="$1" labelSingular="$2" labelPlural="$3" icon="$4"
  "${CURL[@]}" -X PATCH \
    -d "{\"labelSingular\":\"$labelSingular\",\"labelPlural\":\"$labelPlural\",\"icon\":\"$icon\"}" \
    "$TWENTY_BASE/rest/metadata/objects/$id" >/dev/null
  echo "  ✓ renamed object $id -> '$labelSingular' / '$labelPlural'"
}

field_exists() {
  local objectId="$1" fieldName="$2"
  "${CURL[@]}" "$TWENTY_BASE/rest/metadata/objects/$objectId" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
obj = d.get('data', {}).get('object', {}) or d.get('data', {}).get('updateOneObject', {})
fields = obj.get('fields', [])
if isinstance(fields, dict):
    fields = [e.get('node', {}) for e in fields.get('edges', [])]
for f in fields:
    if f.get('name') == '$fieldName':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# ----- Step 1: rename Company -> Retailer ------------------------------------

echo "[1/4] Rename Company -> Retailer"
COMPANY=$(object_by_name "company")
if [ -n "$COMPANY" ]; then
  COMPANY_ID=$(echo "$COMPANY" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  CURRENT_LABEL=$(echo "$COMPANY" | python3 -c "import sys,json; print(json.load(sys.stdin)['labelSingular'])")
  if [ "$CURRENT_LABEL" = "Retailer" ]; then
    echo "  ✓ already renamed (labelSingular = 'Retailer')"
  else
    rename_object "$COMPANY_ID" "Retailer" "Retailers" "IconBuildingStore"
  fi
else
  echo "  ⚠ company object not found, skipping"
fi

# ----- Step 2: rename Person -> Contact --------------------------------------

echo "[2/4] Rename Person -> Contact"
PERSON=$(object_by_name "person")
if [ -n "$PERSON" ]; then
  PERSON_ID=$(echo "$PERSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  CURRENT_LABEL=$(echo "$PERSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['labelSingular'])")
  if [ "$CURRENT_LABEL" = "Contact" ]; then
    echo "  ✓ already renamed (labelSingular = 'Contact')"
  else
    rename_object "$PERSON_ID" "Contact" "Contacts" "IconUserCircle"
  fi
fi

# ----- Step 3: stage fields on Retailer + Staff object + Staff fields --------

echo "[3/4] Add prospectingStage + onboardingStage to Retailer; create Staff object"
python3 <<'PY'
import json, os, ssl, sys, urllib.request, urllib.error, uuid

API = os.environ['TWENTY_API_KEY']
BASE = os.environ.get('TWENTY_BASE', 'https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com')
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def http(method, path, body=None):
    req = urllib.request.Request(
        f'{BASE}{path}',
        data=(json.dumps(body).encode() if body is not None else None),
        headers={'Authorization': f'Bearer {API}', 'Content-Type': 'application/json'},
        method=method)
    with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
        return json.loads(r.read())

def opt(value, label, position, color):
    return {'id': str(uuid.uuid4()), 'value': value, 'label': label, 'position': position, 'color': color}

# Find object ids
objects = http('GET', '/rest/metadata/objects')['data']['objects']
by_name = {o['nameSingular']: o for o in objects}
retailer_id = by_name['company']['id']

# 3a. Add prospectingStage if missing
existing_field_names = {f.get('name') for f in (by_name['company'].get('fields') or [])}
if 'prospectingStage' not in existing_field_names:
    http('POST', '/rest/metadata/fields', {
        'objectMetadataId': retailer_id, 'type': 'SELECT',
        'name': 'prospectingStage', 'label': 'Prospecting Stage',
        'description': 'BDM-owned prospecting pipeline stage',
        'icon': 'IconRocket',
        'options': [
            opt('PROSPECT', 'Prospect', 0, 'gray'),
            opt('ENGAGED', 'Engaged', 1, 'blue'),
            opt('ON_HOLD', 'On Hold', 2, 'yellow'),
            opt('DEAD', 'Dead', 3, 'red'),
            opt('CONVERTED', 'Converted', 4, 'green'),
        ],
        'defaultValue': "'PROSPECT'",
    })
    print('  ✓ created prospectingStage')
else:
    print('  ✓ prospectingStage already exists')

# 3b. Add onboardingStage if missing
if 'onboardingStage' not in existing_field_names:
    http('POST', '/rest/metadata/fields', {
        'objectMetadataId': retailer_id, 'type': 'SELECT',
        'name': 'onboardingStage', 'label': 'Onboarding Stage',
        'description': 'Sales Support-owned onboarding pipeline stage. Auto-set to File Collection when prospectingStage = Converted (workflow configured in UI).',
        'icon': 'IconChecklist',
        'options': [
            opt('FILE_COLLECTION', 'File Collection', 0, 'gray'),
            opt('SMT_SIGN_OFF', 'SMT Sign Off', 1, 'blue'),
            opt('SENT_TO_LENDER', 'Sent to Lender', 2, 'purple'),
            opt('LENDER_APPROVED', 'Lender Approved', 3, 'turquoise'),
            opt('TECH_SETUP', 'Tech Setup', 4, 'orange'),
            opt('LIVE', 'Live', 5, 'green'),
            opt('DEAD', 'Dead', 6, 'red'),
        ],
    })
    print('  ✓ created onboardingStage')
else:
    print('  ✓ onboardingStage already exists')

# 3c. Create Staff custom object if missing
if 'staffMember' not in by_name:
    resp = http('POST', '/rest/metadata/objects', {
        'nameSingular': 'staffMember',
        'namePlural': 'staffMembers',
        'labelSingular': 'Staff Member',
        'labelPlural': 'Staff',
        'description': 'Confidential staff records: personal details, contracts, salary, holiday. Visible only to HR Admin role.',
        'icon': 'IconUserShield',
    })
    staff_id = resp['data']['createOneObject']['id']
    print(f'  ✓ created Staff object id={staff_id}')

    # Staff fields
    fields = [
        {'type': 'TEXT', 'name': 'fullName', 'label': 'Full Name', 'description': 'Legal full name', 'icon': 'IconUser'},
        {'type': 'DATE_TIME', 'name': 'dateOfBirth', 'label': 'Date of Birth', 'icon': 'IconCake'},
        {'type': 'EMAILS', 'name': 'personalEmail', 'label': 'Personal Email', 'description': 'Personal (non-work) email', 'icon': 'IconMail'},
        {'type': 'PHONES', 'name': 'personalPhone', 'label': 'Personal Phone', 'icon': 'IconPhone'},
        {'type': 'ADDRESS', 'name': 'homeAddress', 'label': 'Home Address', 'icon': 'IconHome'},
        {'type': 'TEXT', 'name': 'nationalInsuranceNumber', 'label': 'National Insurance Number', 'description': 'UK NI number', 'icon': 'IconId'},
        {'type': 'TEXT', 'name': 'emergencyContact', 'label': 'Emergency Contact', 'description': 'Name + phone of emergency contact', 'icon': 'IconAlertTriangle'},
        {'type': 'TEXT', 'name': 'jobTitle', 'label': 'Job Title', 'icon': 'IconBriefcase'},
        {'type': 'SELECT', 'name': 'department', 'label': 'Department', 'icon': 'IconUsersGroup',
         'options': [opt('COMMERCIAL', 'Commercial', 0, 'blue'), opt('SALES_SUPPORT', 'Sales Support', 1, 'purple'),
                     opt('TECH', 'Tech', 2, 'turquoise'), opt('OPERATIONS', 'Operations', 3, 'green'),
                     opt('COMPLIANCE', 'Compliance', 4, 'orange'), opt('HR', 'HR', 5, 'pink'),
                     opt('FINANCE', 'Finance', 6, 'yellow'), opt('LEADERSHIP', 'Leadership', 7, 'red')],
         'defaultValue': "'COMMERCIAL'"},
        {'type': 'SELECT', 'name': 'contractType', 'label': 'Contract Type', 'icon': 'IconFileContract',
         'options': [opt('PAYE_PERMANENT', 'PAYE Permanent', 0, 'green'), opt('PAYE_FIXED_TERM', 'PAYE Fixed Term', 1, 'blue'),
                     opt('SELF_EMPLOYED', 'Self Employed', 2, 'purple'), opt('CONTRACTOR', 'Contractor', 3, 'orange'),
                     opt('INTERN', 'Intern', 4, 'gray')],
         'defaultValue': "'PAYE_PERMANENT'"},
        {'type': 'DATE_TIME', 'name': 'startDate', 'label': 'Start Date', 'icon': 'IconCalendarPlus'},
        {'type': 'DATE_TIME', 'name': 'endDate', 'label': 'End Date', 'description': 'Date employment ended, if applicable', 'icon': 'IconCalendarMinus'},
        {'type': 'SELECT', 'name': 'employmentStatus', 'label': 'Employment Status', 'icon': 'IconUserCheck',
         'options': [opt('ACTIVE', 'Active', 0, 'green'), opt('PROBATION', 'Probation', 1, 'yellow'),
                     opt('NOTICE', 'Notice', 2, 'orange'), opt('LEFT', 'Left', 3, 'red'),
                     opt('ON_LEAVE', 'On Leave', 4, 'gray')],
         'defaultValue': "'ACTIVE'"},
        {'type': 'CURRENCY', 'name': 'salary', 'label': 'Salary', 'description': 'Annual gross salary', 'icon': 'IconCoin'},
        {'type': 'BOOLEAN', 'name': 'bonusEligible', 'label': 'Bonus Eligible', 'icon': 'IconAward'},
        {'type': 'TEXT', 'name': 'compensationNotes', 'label': 'Compensation Notes', 'description': 'Bonus structure, equity, allowances, OTE detail', 'icon': 'IconNotes'},
        {'type': 'NUMBER', 'name': 'holidayAllowanceDays', 'label': 'Holiday Allowance (Days)', 'description': 'Annual entitlement', 'icon': 'IconBeach'},
        {'type': 'NUMBER', 'name': 'holidayDaysUsed', 'label': 'Holiday Days Used (YTD)', 'icon': 'IconCalendarStats'},
        {'type': 'TEXT', 'name': 'contractDocLink', 'label': 'Contract Document Link', 'description': 'URL to signed employment contract (DocuSign / SharePoint)', 'icon': 'IconFileText'},
    ]
    for f in fields:
        try:
            http('POST', '/rest/metadata/fields', {**f, 'objectMetadataId': staff_id})
            print(f"    ✓ {f['name']}")
        except urllib.error.HTTPError as e:
            print(f"    ✗ {f['name']}: {e.code} {e.read().decode()[:120]}")
else:
    print('  ✓ Staff object already exists')
PY

# ----- Step 4: HR Admin role + Member-cannot-see-Staff override --------------

echo "[4/4] Configure HR Admin role + restrict Member access to Staff"
python3 <<'PY'
import json, os, ssl, urllib.request

API = os.environ['TWENTY_API_KEY']
BASE = os.environ.get('TWENTY_BASE', 'https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com')
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def gql(query, variables=None):
    body = {'query': query}
    if variables: body['variables'] = variables
    req = urllib.request.Request(f'{BASE}/metadata',
        data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {API}', 'Content-Type': 'application/json'},
        method='POST')
    with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
        return json.loads(r.read())

# Find Member role and Staff object
roles = gql('{ getRoles { id label } }')['data']['getRoles']
member = next((r for r in roles if r['label'] == 'Member'), None)
hr_admin = next((r for r in roles if r['label'] == 'HR Admin'), None)

objects = gql('{ objects(paging:{first:200}) { edges { node { id nameSingular } } } }')
staff = next((e['node'] for e in objects['data']['objects']['edges']
              if e['node']['nameSingular'] == 'staffMember'), None)
if not staff:
    print('  ✗ staffMember object not found')
    raise SystemExit(1)

# Create HR Admin role if missing
if not hr_admin:
    resp = gql('''
        mutation($input: CreateRoleInput!) {
            createOneRole(createRoleInput: $input) {
                id label
            }
        }
    ''', {'input': {
        'label': 'HR Admin',
        'description': 'Read/write access to confidential Staff records.',
        'icon': 'IconUserShield',
        'canReadAllObjectRecords': True,
        'canUpdateAllObjectRecords': True,
        'canDestroyAllObjectRecords': True,
        'canSoftDeleteAllObjectRecords': True,
    }})
    print(f"  ✓ created HR Admin role id={resp['data']['createOneRole']['id']}")
else:
    print(f"  ✓ HR Admin role already exists id={hr_admin['id']}")

# Deny Member access to Staff (idempotent — upsert)
if member:
    resp = gql('''
        mutation($input: UpsertObjectPermissionsInput!) {
            upsertObjectPermissions(upsertObjectPermissionsInput: $input) {
                objectMetadataId canReadObjectRecords canUpdateObjectRecords
            }
        }
    ''', {'input': {
        'roleId': member['id'],
        'objectPermissions': [{
            'objectMetadataId': staff['id'],
            'canReadObjectRecords': False,
            'canUpdateObjectRecords': False,
            'canDestroyObjectRecords': False,
            'canSoftDeleteObjectRecords': False,
        }]
    }})
    print(f"  ✓ Member role denied access to Staff")
PY

echo ""
echo "Done. Open the workspace and check:"
echo "  - Sidebar shows Retailers, Contacts, Staff"
echo "  - Open a Retailer record, both stage fields are present"
echo "  - Settings -> Roles shows 'HR Admin' alongside Member and Admin"
