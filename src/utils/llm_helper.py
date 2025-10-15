# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import json
from pathlib import Path
from google.oauth2 import service_account

import langchain_google_genai as google_genai
import langchain_openai as openai

# Updated to latest Gemini model
_GEMINI_MODEL = "gemini-2.5-flash"
_OPENAI_MODEL = "gpt-3.5-turbo"


def _load_google_credentials(config):
  """Load Google credentials from JSON file or API key."""
  credentials = None
  
  # Check for JSON credentials file path
  if hasattr(config, 'google_credentials_path') and config.google_credentials_path:
    try:
      credentials_path = Path(config.google_credentials_path)
      if credentials_path.exists():
        credentials = service_account.Credentials.from_service_account_file(
            str(credentials_path),
            scopes=['https://www.googleapis.com/auth/generative-language']
        )
        print(f"Loaded Google credentials from file: {credentials_path}")
        return credentials
      else:
        print(f"Credentials file not found: {credentials_path}")
    except Exception as e:
      print(f"Error loading credentials from file: {e}")
  
  # Check for JSON credentials content
  if hasattr(config, 'google_credentials_json') and config.google_credentials_json:
    try:
      if isinstance(config.google_credentials_json, str):
        credentials_info = json.loads(config.google_credentials_json)
      else:
        credentials_info = config.google_credentials_json
      
      credentials = service_account.Credentials.from_service_account_info(
          credentials_info,
          scopes=['https://www.googleapis.com/auth/generative-language']
      )
      print("Loaded Google credentials from JSON content")
      return credentials
    except Exception as e:
      print(f"Error loading credentials from JSON content: {e}")
  
  # Fallback to API key
  if hasattr(config, 'google_api_key') and config.google_api_key:
    os.environ["GOOGLE_API_KEY"] = config.google_api_key
    print("Using Google API key for authentication")
    return None  # Return None to indicate API key auth
  
  return None


# Select the LLM to use based on the settings set in the UI.
def select_llm(config):
  # Try Google/Gemini first
  credentials = _load_google_credentials(config)
  
  if credentials is not None or (hasattr(config, 'google_api_key') and config.google_api_key):
    print(f"Picked {_GEMINI_MODEL} model for summarizing")
    
    if credentials:
      # Use service account credentials
      return google_genai.ChatGoogleGenerativeAI(
          model=_GEMINI_MODEL,
          credentials=credentials,
          max_output_tokens=8192,
          temperature=0.2,
          top_p=0.98,
          top_k=40,
      )
    else:
      # Use API key (already set in environment)
      return google_genai.ChatGoogleGenerativeAI(
          model=_GEMINI_MODEL,
          max_output_tokens=8192,
          temperature=0.2,
          top_p=0.98,
          top_k=40,
      )
  else:
    print("Picked OpenAI 3.5-turbo model for summarizing")
    return openai.OpenAI(
        model_name=_OPENAI_MODEL,
        temperature=0.2,
        max_tokens=1024,
        openai_api_key=config.openai_api_key,
    )
