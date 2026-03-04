import requests
import sys

base_url = "http://127.0.0.1:8000/api/v1"

# 1. Login
login_res = requests.post(
    f"{base_url}/auth/login",
    json={"email": "faculty@internhub.dev", "password": "Demo@1234"}
)
if login_res.status_code != 200:
    print("Login failed:", login_res.text)
    sys.exit(1)

token = login_res.json()["access_token"]
print("Logged in successfully.")

# 2. Create Internship
data = {
    "title": "aef JB",
    "company_name": "DQEwnnb",
    "description": "dwj;n",
    "mode": "hybrid",
    "poster_url": None,
    "location": "edmn n",
    "required_skills": ["edwqj", "bdwqq"],
    "stipend_min": None,
    "stipend_max": None,
    "openings": 1,
    "duration_weeks": None,
    "min_cgpa": None,
    "application_deadline": None
}

headers = {"Authorization": f"Bearer {token}"}
print("Posting internship...")
try:
    post_res = requests.post(
        f"{base_url}/faculty/internships",
        json=data,
        headers=headers
    )
    print("Status code:", post_res.status_code)
    print("Response text:", post_res.text)
except Exception as e:
    print("Network Error:", str(e))
