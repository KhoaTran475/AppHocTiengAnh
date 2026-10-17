import sys
from supabase import create_client

SUPABASE_URL = "https://tcbcmzfdidcwblvfmckb.supabase.co"
# Anon key used in Flutter app:
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjYmNtemZkaWRjd2JsdmZtY2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNzE4NTQsImV4cCI6MjEwNjg0Nzg1NH0.0nVR69yNJhNMDFXRpED4R6qHfsNMfMlcKJOURYojn6c"

supabase = create_client(SUPABASE_URL, ANON_KEY)

print("--- Testing Insert with Anon Key ---")
try:
    res = supabase.table("profiles").upsert({
        "username": "jett",
        "role": "learner"
    }, on_conflict="username").execute()
    print("SUCCESS with Anon Key:", res)
except Exception as e:
    print("ERROR with Anon Key:", e)

# Service key from import_data.py
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjYmNtemZkaWRjd2JsdmZtY2tiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTI3MTg1NCwiZXhwIjoyMTA2ODQ3ODU0fQ.F6r_J2HlEp_YROwMDmVLpKo6talLid_EbEbxGAf0no4"
supabase_service = create_client(SUPABASE_URL, SERVICE_KEY)

print("--- Testing Insert with Service Role Key ---")
try:
    res = supabase_service.table("profiles").upsert({
        "username": "jett",
        "role": "learner"
    }, on_conflict="username").execute()
    print("SUCCESS with Service Key:", res)
except Exception as e:
    print("ERROR with Service Key:", e)
