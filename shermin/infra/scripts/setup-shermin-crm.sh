#!/usr/bin/env bash
# Configure the Shermin CRM workspace on a freshly deployed Twenty.
# Idempotent — re-running on an already-configured workspace is safe; existing
# objects / fields / roles / views / workflow shells / logo are detected and skipped.
#
# What this does (in order):
#   1. Renames Company -> Retailer, Person -> Contact (label only, apiName preserved).
#   2. Adds two SELECT fields to Retailer for the two-pipeline kanban model:
#      `prospectingStage` (BDM-owned: Prospect, Engaged, On Hold, Dead, Converted)
#      `onboardingStage`  (Sales Support-owned: File Collection ... Live, Dead)
#   3. Creates a `staffMember` custom object with 19 fields covering personal
#      details, employment, compensation, holiday, contract.
#   4. Creates an "HR Admin" role and denies the Member role any access to
#      the staffMember object — Staff is visible only to Admin + HR Admin.
#   5. Configures default Kanban views: "Prospecting" (groups by prospectingStage)
#      and "Onboarding" (groups by onboardingStage), both workspace-visible.
#   6. Creates a workflow shell "Auto-advance retailer to onboarding when converted"
#      (in DRAFT). The trigger + step content needs a UI step (see below).
#   7. Uploads the Stax logo if STAX_LOGO env var points to a file.
#
# Prerequisites:
#   TWENTY_BASE     URL of the workspace (default: v0 ALB)
#   TWENTY_API_KEY  Workspace API key with admin scope. Generate at
#                   Settings -> API & Webhooks -> Create API Key.
#   STAX_LOGO       Optional. Path to Stax logo SVG/PNG to upload. Defaults
#                   to ~/Desktop/.../stax-training-platform/public/brand/stax-logo.svg
#                   on Barney's machine. Skipped if file doesn't exist.
#
# Things this script does NOT do (must be done via Twenty UI):
#   - Workflow trigger + steps content. Twenty's WorkflowVersionStep API is
#     gated by UserAuthGuard, not accessible via API key. After this script,
#     open Settings -> Workflows -> "Auto-advance retailer to onboarding..."
#     and add the trigger (DATABASE_EVENT, watch prospectingStage on Retailer)
#     + filter (prospectingStage = Converted) + Update Record action
#     (set onboardingStage = File Collection on the same retailer). Then activate.
#   - Per-stage prescriptive checklists (deferred per Barney's spec).
#   - Assigning the HR Admin role to specific people (Settings -> Members).

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

echo "[1/7] Rename Company -> Retailer"
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

echo "[2/7] Rename Person -> Contact"
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

echo "[3/7] Add prospectingStage + onboardingStage to Retailer; create Staff object"
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

echo "[4/7] Configure HR Admin role + restrict Member access to Staff"
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

# ----- Step 5: Default Kanban views (Prospecting + Onboarding) ---------------

echo "[5/7] Configure default Kanban views"
python3 <<'PY'
import json, os, ssl, urllib.request

API = os.environ['TWENTY_API_KEY']
BASE = os.environ.get('TWENTY_BASE', 'https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com')
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def gql(query, variables=None):
    body = {'query': query}
    if variables: body['variables'] = variables
    req = urllib.request.Request(f'{BASE}/metadata', data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {API}', 'Content-Type': 'application/json'}, method='POST')
    with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
        return json.loads(r.read())

# Find Retailer object + stage field IDs
objects = gql('{ objects(paging:{first:200}) { edges { node { id nameSingular } } } }')
retailer = next((e['node'] for e in objects['data']['objects']['edges']
                 if e['node']['nameSingular'] == 'company'), None)
RETAILER_ID = retailer['id']

fields = gql('query($id:UUID!){ object(id:$id){ fields(paging:{first:100}){ edges { node { id name type } } } } }', {'id': RETAILER_ID})
field_id = {e['node']['name']: e['node']['id'] for e in fields['data']['object']['fields']['edges']}
PROSPECTING_FIELD = field_id.get('prospectingStage')
ONBOARDING_FIELD = field_id.get('onboardingStage')

if not PROSPECTING_FIELD or not ONBOARDING_FIELD:
    print('  ✗ stage fields not found, skipping kanban setup')
    raise SystemExit(0)

# Find existing Retailer kanban views
views = gql('{ getViews { id name type objectMetadataId mainGroupByFieldMetadataId } }')['data']['getViews']
retailer_kanbans = [v for v in views if v['objectMetadataId'] == RETAILER_ID and v['type'] == 'KANBAN']
existing_by_name = {v['name']: v for v in retailer_kanbans}

# Ensure "Prospecting" exists / is correct
if 'Prospecting' in existing_by_name:
    v = existing_by_name['Prospecting']
    if v['mainGroupByFieldMetadataId'] != PROSPECTING_FIELD:
        gql('mutation{ updateView(id:"' + v['id'] + '", input:{mainGroupByFieldMetadataId:"' + PROSPECTING_FIELD + '", icon:"IconRocket"}){ id } }')
        print('  ✓ updated Prospecting kanban grouping')
    else:
        print('  ✓ Prospecting kanban already correct')
else:
    # Look for the auto-generated "All Retailers" KANBAN that ships with the object
    # and rename it to Prospecting if its grouping is right; otherwise create fresh.
    auto = next((v for v in retailer_kanbans
                 if v['mainGroupByFieldMetadataId'] == PROSPECTING_FIELD), None)
    if auto:
        gql('mutation{ updateView(id:"' + auto['id'] + '", input:{name:"Prospecting", icon:"IconRocket"}){ id } }')
        print('  ✓ renamed auto-kanban to Prospecting')
    else:
        gql('mutation{ createView(input:{name:"Prospecting", objectMetadataId:"' + RETAILER_ID
            + '", type:KANBAN, icon:"IconRocket", mainGroupByFieldMetadataId:"' + PROSPECTING_FIELD
            + '", visibility:WORKSPACE, position:0}){ id } }')
        print('  ✓ created Prospecting kanban')

# Ensure "Onboarding" exists
if 'Onboarding' in existing_by_name:
    print('  ✓ Onboarding kanban already exists')
else:
    gql('mutation{ createView(input:{name:"Onboarding", objectMetadataId:"' + RETAILER_ID
        + '", type:KANBAN, icon:"IconChecklist", mainGroupByFieldMetadataId:"' + ONBOARDING_FIELD
        + '", visibility:WORKSPACE, position:1}){ id } }')
    print('  ✓ created Onboarding kanban')
PY

# ----- Step 6: Workflow shell (trigger/steps must be filled in via UI) -------

echo "[6/7] Create workflow shell (Auto-advance retailer to onboarding when converted)"
python3 <<'PY'
import json, os, ssl, urllib.request

API = os.environ['TWENTY_API_KEY']
BASE = os.environ.get('TWENTY_BASE', 'https://twenty-shermin-v0-alb-2090009733.eu-west-2.elb.amazonaws.com')
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def gql(endpoint, query, variables=None):
    body = {'query': query}
    if variables: body['variables'] = variables
    req = urllib.request.Request(f'{BASE}/{endpoint}', data=json.dumps(body).encode(),
        headers={'Authorization': f'Bearer {API}', 'Content-Type': 'application/json'}, method='POST')
    with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
        return json.loads(r.read())

WF_NAME = 'Auto-advance retailer to onboarding when converted'

existing = gql('graphql', '{ workflows{ edges{ node{ id name } } } }')['data']['workflows']['edges']
match = next((e['node'] for e in existing if e['node']['name'] == WF_NAME), None)
if match:
    print(f'  ✓ workflow shell already exists id={match["id"]}')
else:
    resp = gql('graphql', '''
      mutation($data: WorkflowCreateInput!) {
        createWorkflow(data: $data) { id name }
      }
    ''', {'data': {'name': WF_NAME, 'position': 10}})
    if 'errors' in resp:
        print(f'  ✗ failed to create workflow: {resp["errors"][0]["message"]}')
    else:
        print(f'  ✓ created workflow shell id={resp["data"]["createWorkflow"]["id"]}')
        print("    NOTE: Twenty's workflow content API requires user-session auth, not API keys.")
        print('    Open Settings -> Workflows -> this workflow and add trigger + steps in UI.')
        print('    Walkthrough in shermin/docs/v1-customisation.md')
PY

# ----- Step 7: Logo upload (optional) ----------------------------------------

LOGO_DEFAULT="/Users/barneygoodman/Desktop/Miscellaneous/Desktop - Barney's MacBook Pro 2024/BG Consulting Ltd/CLAUDE COWORK/PROJECTS/stax-training-platform/public/brand/stax-logo.svg"
LOGO_PATH="${STAX_LOGO:-$LOGO_DEFAULT}"

echo "[7/7] Upload Stax logo"
if [ -f "$LOGO_PATH" ]; then
  # Check if logo is already set
  HAS_LOGO=$("${CURL[@]}" -X POST -d '{"query":"{ currentWorkspace { logo } }"}' \
    "$TWENTY_BASE/metadata" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if d['data']['currentWorkspace'].get('logo') else 'no')")

  if [ "$HAS_LOGO" = "yes" ]; then
    echo "  ✓ workspace logo already set (skip; delete via UI to re-upload)"
  else
    # Stage to /tmp to dodge spaces in the source path
    cp "$LOGO_PATH" /tmp/stax-logo-upload.svg
    RESP=$(curl --silent --insecure --show-error \
      -H "Authorization: Bearer $TWENTY_API_KEY" \
      -H "x-apollo-operation-name: UploadWorkspaceLogo" \
      -F 'operations={"query":"mutation($file:Upload!){ uploadWorkspaceLogo(file:$file){ path } }","variables":{"file":null}}' \
      -F 'map={"0":["variables.file"]}' \
      -F '0=@/tmp/stax-logo-upload.svg;type=image/svg+xml' \
      "$TWENTY_BASE/metadata")
    rm -f /tmp/stax-logo-upload.svg
    if echo "$RESP" | grep -q '"path"'; then
      echo "  ✓ uploaded logo from $LOGO_PATH"
    else
      echo "  ✗ logo upload failed: $RESP" | head -c 300
    fi
  fi
else
  echo "  ⚠ logo not found at $LOGO_PATH (set STAX_LOGO env var to override; skipping)"
fi

echo ""
echo "Done. In the running Twenty workspace, check:"
echo "  - Sidebar shows Retailers, Contacts, Staff"
echo "  - Open Retailers, two kanban views: 'Prospecting' + 'Onboarding'"
echo "  - Open a Retailer record, both stage fields are present"
echo "  - Settings -> Roles shows 'HR Admin' alongside Member and Admin"
echo "  - Top-left workspace switcher shows the Stax logo (hard-refresh if not)"
echo "  - Settings -> Workflows shows 'Auto-advance retailer...' (DRAFT, needs UI to fill)"
