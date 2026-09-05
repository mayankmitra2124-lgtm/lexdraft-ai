from sqlalchemy import create_engine, Column, Integer, String, JSON, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import declarative_base, sessionmaker
from datetime import datetime

# Phase 1, 8 & 10: PostgreSQL Schema
DATABASE_URL = "postgresql://lexdraft:password@localhost:5432/lexdraft_evidence"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class EvidenceMetadata(Base):
    """Phase 1: Evidence Registration replacing SQLite"""
    __tablename__ = "evidence_metadata"
    
    evidence_id = Column(String(64), primary_key=True, index=True)
    evidence_type = Column(String(20))
    s3_uri = Column(String(255))
    ingested_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String(50))

class KnowledgeGraphNode(Base):
    """Phase 8: Case Knowledge Graph Nodes (Parties, Facts, Events)"""
    __tablename__ = "knowledge_graph_nodes"
    
    node_id = Column(String(64), primary_key=True)
    node_type = Column(String(50)) # PARTY, FACT, EVENT, CLAIM
    data = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)

class AuditLog(Base):
    """Phase 10: Synchronous Audit Trail for Model Reliability"""
    __tablename__ = "audit_log"
    
    log_id = Column(Integer, primary_key=True, index=True)
    evidence_id = Column(String(64), ForeignKey("evidence_metadata.evidence_id"))
    field_name = Column(String(255))
    resolved_value = Column(Text)
    resolution_strategy = Column(String(50)) # CONFIRMED_VOTING, ESCALATE, CONFIRMED_AGREEMENT
    models_involved = Column(JSON) # e.g., {"Gemini": "val1", "GPT": "val2"}
    timestamp = Column(DateTime, default=datetime.utcnow)

# Ensure tables are created
# Base.metadata.create_all(bind=engine)
