"""
K2 Think V2 service layer.

This module centralizes all model calls so the app can use K2 as the primary
reasoning engine while still supporting lightweight "specialized agent" context
switching in-memory.
"""

from __future__ import annotations

import json
import logging
import os
import uuid
from typing import Any

import httpx

log = logging.getLogger("k2")

K2_BASE_URL = os.getenv("K2_BASE_URL", "https://api.k2think.ai/v1").rstrip("/")
K2_MODEL = os.getenv("K2_MODEL", "MBZUAI-IFM/K2-Think-v2")


class K2Error(Exception):
    """Raised when the K2 API request fails."""


class K2AuthError(K2Error):
    """Raised when the K2 API key is missing or rejected."""


class K2Service:
    def __init__(self):
        self._client: httpx.AsyncClient | None = None
        self._api_key: str | None = None
        self._ready = False
        self._main_context_doc: str | None = None
        self._agent_contexts: dict[str, str] = {}

    @property
    def ready(self) -> bool:
        return self._ready

    async def start(self):
        self._api_key = os.getenv("K2_API_KEY", "").strip()
        if not self._api_key:
            log.warning("K2_API_KEY not set. AI routes will be unavailable.")
            self._ready = False
            return

        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(90.0, connect=10.0),
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
        )
        self._ready = True
        log.info("K2 service initialized with model %s", K2_MODEL)

    async def stop(self):
        if self._client:
            await self._client.aclose()
            self._client = None
        self._ready = False

    async def _request(
        self,
        messages: list[dict[str, str]],
        *,
        temperature: float = 0.4,
        max_tokens: int = 4096,
    ) -> str:
        if not self._ready or not self._client:
            raise K2AuthError("K2 service not ready. Set K2_API_KEY in backend/.env")

        payload = {
            "model": K2_MODEL,
            "messages": messages,
            "stream": False,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

        try:
            response = await self._client.post(f"{K2_BASE_URL}/chat/completions", json=payload)
        except httpx.HTTPError as exc:
            raise K2Error(f"K2 request failed: {exc}") from exc

        if response.status_code in {401, 403}:
            raise K2AuthError("K2 API key rejected by upstream service")
        if response.status_code >= 400:
            raise K2Error(f"K2 API error {response.status_code}: {response.text}")

        data = response.json()
        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise K2Error(f"Unexpected K2 response shape: {json.dumps(data)[:600]}") from exc

        if isinstance(content, list):
            return "".join(
                item.get("text", "")
                for item in content
                if isinstance(item, dict)
            ).strip()
        if isinstance(content, str):
            return content.strip()

        raise K2Error("K2 returned an unsupported content format")

    async def generate_text(self, prompt: str, system_instruction: str = "") -> str:
        messages = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})
        messages.append({"role": "user", "content": prompt})
        return await self._request(messages, temperature=0.5)

    async def generate_json(self, prompt: str, system_instruction: str = "") -> Any:
        text = await self.generate_text(
            (
                prompt
                + "\n\nIMPORTANT: Respond with valid JSON only. "
                + "No markdown fences. No explanation."
            ),
            system_instruction=system_instruction or "Return valid JSON only.",
        )

        cleaned = text.strip()
        if cleaned.startswith("```"):
            lines = [line for line in cleaned.splitlines() if not line.strip().startswith("```")]
            cleaned = "\n".join(lines).strip()

        return json.loads(cleaned)

    async def build_knowledge_document(self, prompt: str) -> str:
        return await self.generate_text(
            prompt,
            system_instruction=(
                "You are preparing an organized knowledge brief for a reasoning assistant. "
                "Be specific, structured, and grounded in the provided material."
            ),
        )

    async def send_prompt(self, prompt: str, system_instruction: str = "") -> str:
        context_prefix = ""
        if self._main_context_doc:
            context_prefix = (
                "Use the following working memory when answering. "
                "Cite or lean on it when relevant.\n\n"
                f"{self._main_context_doc}\n\n"
            )
        return await self.generate_text(context_prefix + prompt, system_instruction=system_instruction)

    async def send_prompt_to_agent(self, agent_url: str, prompt: str, system_instruction: str = "") -> str:
        context_doc = self._agent_contexts.get(agent_url, "")
        full_prompt = prompt
        if context_doc:
            full_prompt = (
                "Use this specialized context for the conversation.\n\n"
                f"{context_doc}\n\n"
                f"{prompt}"
            )
        return await self.generate_text(full_prompt, system_instruction=system_instruction)

    async def create_topic_agent(self, agent_name: str, context_doc: str) -> str:
        agent_url = f"k2://agent/{uuid.uuid4()}-{agent_name.lower().replace(' ', '-')[:24]}"
        self._agent_contexts[agent_url] = context_doc
        return agent_url

    async def update_agent_knowledge(self, context_doc: str):
        self._main_context_doc = context_doc

    def store_agent_context(self, agent_url: str, context_doc: str):
        self._agent_contexts[agent_url] = context_doc


k2_service = K2Service()
