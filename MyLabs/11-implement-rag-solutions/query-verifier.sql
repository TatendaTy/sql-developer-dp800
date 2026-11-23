USE AdventureWorks2025;
GO

/* -------------------------------------------------
   2️⃣  (Re)create the database‑scoped credential
       Identity = HTTPEndpointHeaders  (no auth needed for Ollama)
   ------------------------------------------------- */
DECLARE @NgrokUrl nvarchar(200) = N'${NGROK_URL}';   -- Set in .env


/* -------------------------------------------------
   3️⃣  Grant the needed permission so the current user can use the credential
   ------------------------------------------------- */
-- REFERENCES permission allows the credential to be referenced by external objects
GRANT REFERENCES ON DATABASE SCOPED CREDENTIAL::[${NGROK_URL}] TO [public];
GO

/* -------------------------------------------------
   4️⃣  Verify the credential exists and its permission
   ------------------------------------------------- */
SELECT 
    credential_id,
    name,
    credential_identity,
    create_date,
    modify_date,
    has_perms_by_name(name, 'DATABASE SCOPED CREDENTIAL', 'REFERENCES') AS has_reference_perm
FROM sys.database_scoped_credentials
WHERE name = '${NGROK_URL}';
GO

/* -------------------------------------------------
   6️⃣  Quick test – call Ollama chat model
   ------------------------------------------------- */
DECLARE @returnValue int;
DECLARE @response nvarchar(max);

EXECUTE @returnValue = sp_invoke_external_rest_endpoint
    @url = @NgrokUrl + N'/api/chat',
    @method = 'POST',
    @payload = N'{
        "model":"qwen2.5-coder:1.5b",
        "messages":[{"role":"user","content":"Hello, who are you?"}],
        "stream":false,
        "options":{"temperature":0.7,"num_predict":50}
    }',
    @credential = @NgrokUrl,
    @response = @response OUTPUT;

SELECT 
    @returnValue AS ReturnCode,
    @response AS RawResponse;
GO