"""Test validazione build."""

import pytest

from mechamind_mcp.client import validate_build
from mechamind_mcp.rules import DEFAULT_BUILD


def test_default_build_valid():
    validate_build(DEFAULT_BUILD)


def test_build_sum_must_be_100():
    bad = dict(DEFAULT_BUILD)
    bad["hull"] = 25
    with pytest.raises(ValueError, match="100"):
        validate_build(bad)
