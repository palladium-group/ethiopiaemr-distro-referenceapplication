import json
import os
import re
import time
import uuid
from datetime import datetime, timezone
from typing import Any
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from pydicom.dataset import Dataset, FileDataset, FileMetaDataset
from pydicom.uid import ExplicitVRLittleEndian, generate_uid


def _worklists_dir() -> Path:
    return Path(os.environ.get("WORKLISTS_DIR", "/worklists")).resolve()


def _sanitize_name(name: str) -> str:
    name = name.strip()
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
    if not name:
        raise ValueError("Empty worklist name")
    return name


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _as_dicom_date(dt: datetime) -> str:
    return dt.strftime("%Y%m%d")


def _as_dicom_time(dt: datetime) -> str:
    return dt.strftime("%H%M%S")


def _build_mwl_file(fields: dict[str, Any]) -> FileDataset:
    """
    Build a DICOM file that Orthanc Worklists plugin can read as a worklist item.
    The Worklists plugin expects real DICOM datasets (not text dumps).
    """
    # Modality Worklist Information Model - FIND
    mwl_uid = "1.2.840.10008.5.1.4.31"

    file_meta = FileMetaDataset()
    file_meta.FileMetaInformationVersion = b"\x00\x01"
    file_meta.MediaStorageSOPClassUID = mwl_uid
    file_meta.MediaStorageSOPInstanceUID = generate_uid()
    file_meta.TransferSyntaxUID = ExplicitVRLittleEndian
    file_meta.ImplementationClassUID = generate_uid(prefix="1.2.826.0.1.3680043.10.543.")  # pydicom-like root

    ds = FileDataset(None, {}, file_meta=file_meta, preamble=b"\0" * 128)
    ds.is_little_endian = True
    ds.is_implicit_VR = False

    now = _now_utc()
    ds.SOPClassUID = mwl_uid
    ds.SOPInstanceUID = file_meta.MediaStorageSOPInstanceUID

    ds.SpecificCharacterSet = fields.get("SpecificCharacterSet", "ISO_IR 100")

    ds.PatientName = fields.get("PatientName", "DOE^JOHN")
    ds.PatientID = fields.get("PatientID", "P001")
    if "PatientBirthDate" in fields:
        ds.PatientBirthDate = fields["PatientBirthDate"]
    if "PatientSex" in fields:
        ds.PatientSex = fields["PatientSex"]

    ds.AccessionNumber = fields.get("AccessionNumber", "ACC-0001")
    ds.RequestingPhysician = fields.get("RequestingPhysician", "REFDOC^ALICE")

    ds.StudyInstanceUID = fields.get("StudyInstanceUID", generate_uid())
    ds.RequestedProcedureID = fields.get("RequestedProcedureID", "RP-0001")
    ds.RequestedProcedureDescription = fields.get("RequestedProcedureDescription", "Procedure")

    ds.InstanceCreationDate = _as_dicom_date(now)
    ds.InstanceCreationTime = _as_dicom_time(now)

    # ScheduledProcedureStepSequence (0040,0100) is essential for MWL
    sps = Dataset()
    sps.ScheduledStationAETitle = fields.get("ScheduledStationAETitle", os.environ.get("ORTHANC_AET", "ORTHANC"))
    sps.ScheduledProcedureStepStartDate = fields.get(
        "ScheduledProcedureStepStartDate", _as_dicom_date(now)
    )
    sps.ScheduledProcedureStepStartTime = fields.get(
        "ScheduledProcedureStepStartTime", _as_dicom_time(now)
    )
    sps.Modality = fields.get("Modality", "CT")
    sps.ScheduledProcedureStepDescription = fields.get("ScheduledProcedureStepDescription", "Scheduled Step")
    sps.ScheduledProcedureStepID = fields.get("ScheduledProcedureStepID", "SPS-0001")

    if "ScheduledProcedureStepLocation" in fields:
        sps.ScheduledProcedureStepLocation = fields["ScheduledProcedureStepLocation"]
    if "ScheduledPerformingPhysicianName" in fields:
        sps.ScheduledPerformingPhysicianName = fields["ScheduledPerformingPhysicianName"]

    ds.ScheduledProcedureStepSequence = [sps]

    # A few optional, commonly-used tags
    if "AdmissionID" in fields:
        ds.AdmissionID = fields["AdmissionID"]
    if "ReferringPhysicianName" in fields:
        ds.ReferringPhysicianName = fields["ReferringPhysicianName"]

    return ds


class Handler(BaseHTTPRequestHandler):
    server_version = "worklist-writer/1.0"

    def _send(self, status: int, payload: dict | list | str):
        body = payload if isinstance(payload, str) else json.dumps(payload, ensure_ascii=False)
        if not isinstance(body, (bytes, bytearray)):
            body = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802
        path = urlparse(self.path).path
        if path in ("/", "/health", "/healthz"):
            self._send(200, {"ok": True})
            return
        self._send(404, {"error": "not_found"})

    def do_POST(self):  # noqa: N802
        path = urlparse(self.path).path
        if not path.startswith("/worklists/"):
            self._send(404, {"error": "not_found"})
            return

        name = path.removeprefix("/worklists/")
        try:
            name = _sanitize_name(name)
        except ValueError as e:
            self._send(400, {"error": str(e)})
            return

        content_length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(content_length) if content_length > 0 else b""

        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid_json"})
            return

        target_dir = _worklists_dir()
        target_dir.mkdir(parents=True, exist_ok=True)

        filename = name if name.lower().endswith(".wl") else f"{name}.wl"
        out = (target_dir / filename).resolve()

        # Prevent path traversal even after sanitization.
        if target_dir not in out.parents:
            self._send(400, {"error": "invalid_path"})
            return

        # Preferred: Generate a real DICOM worklist file from JSON fields.
        # Back-compat: still allow raw text writes via "wl" (but Orthanc likely won't parse it).
        fields = data.get("fields")
        wl_text = data.get("wl")

        tmp = out.with_suffix(out.suffix + ".tmp")

        if isinstance(fields, dict):
            ds = _build_mwl_file(fields)
            ds.save_as(tmp, write_like_original=False)
            tmp.replace(out)
            self._send(201, {"written": str(out), "format": "dicom"})
            return

        if isinstance(wl_text, str) and wl_text.strip():
            tmp.write_text(wl_text, encoding="utf-8")
            tmp.replace(out)
            self._send(201, {"written": str(out), "format": "text"})
            return

        self._send(
            400,
            {
                "error": "body must contain either object field 'fields' (recommended) or non-empty string field 'wl'",
            },
        )


def main():
    host = os.environ.get("WRITER_HOST", "0.0.0.0")
    port = int(os.environ.get("WRITER_PORT", "8000"))
    httpd = ThreadingHTTPServer((host, port), Handler)
    httpd.serve_forever()


if __name__ == "__main__":
    main()

