USE [AdventureWorks2025];
GO

-- Create a database scoped credential for the local endpoint
-- Ensure a database master key exists (needed for scoped credentials)
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '${DB_MASTER_KEY_PASSWORD}';  -- Set in .env
END
GO

-- -- Credential pointing at the local Ollama host
/* -------------------------------------------------
   2️⃣  Drop & recreate the database‑scoped credential
       (use the exact ngrok HTTPS host; identity = Anonymous
        because Ollama does not require auth)
   ------------------------------------------------- */

-- Drop the external model if it exists
IF EXISTS (SELECT * FROM sys.external_models WHERE name = N'qwen3_embedding_0_6B')
BEGIN
    DROP EXTERNAL MODEL qwen3_embedding_0_6B;
END
GO
   
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = N'${NGROK_URL}')
BEGIN
    DROP DATABASE SCOPED CREDENTIAL [${NGROK_URL}];
END
GO

CREATE DATABASE SCOPED CREDENTIAL [${NGROK_URL}]
WITH IDENTITY = 'HTTPEndpointHeaders',   -- valid identity for unauthenticated HTTPS calls
     SECRET = '{}';            -- Ollama doesn’t use a secret
GO

/*  Create the external model – note the API_FORMAT value must be 'Ollama' (case‑sensitive) */
CREATE EXTERNAL MODEL qwen3_embedding_0_6B
WITH (
    LOCATION = '${OLLAMA_EMBED_URL}',   -- Ollama embeddings endpoint (set in .env)
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'qwen3-embedding:0.6b',
    CREDENTIAL = [${NGROK_URL}]
);
GO

CREATE EXTERNAL MODEL my_chat_model
WITH (
    LOCATION = '${OLLAMA_CHAT_URL}',          -- Ollama chat endpoint (set in .env)
    API_FORMAT = 'Ollama',
    MODEL_TYPE = TEXT_COMPLETION,
    MODEL = 'qwen2.5-coder:1.5b',                 -- must match exactly what you pulled with ollama
    CREDENTIAL = [${NGROK_URL}]
);
GO

-- Enable the feature
EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE;
GO