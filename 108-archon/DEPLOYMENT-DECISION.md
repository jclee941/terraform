# Archon Deployment Decision Required

## Critical Constraint Discovered

Archon **requires Supabase** (PostgreSQL + PGVector) as its database backend. This was NOT replaced by Archon; Archon is an APPLICATION that runs ON TOP of Supabase.

## Options

### Option 1: Use Cloud Supabase (Recommended for MVP)
**Pros:**
- Fastest deployment (no additional infrastructure)
- Managed backups, scaling, monitoring
- Official Supabase dashboard
- Free tier available

**Cons:**
- External dependency
- Data stored outside homelab
- Requires internet connectivity
- Potential latency

**Cost:** Free tier: 500 MB database, 2 GB bandwidth/mo

---

### Option 2: Self-host Supabase (Separate VMID)
**Pros:**
- Full control over data
- No external dependency
- Can use existing infrastructure monitoring

**Cons:**
- Complex deployment (9+ Docker containers)
- Requires separate VMID (suggest 108 or 103)
- Additional 4-6 GB RAM required
- More maintenance overhead
- Postgres upgrades + backups on us

**Resource Requirements:**
- VMID: 108 (or reuse 103 if available)
- RAM: 4-6 GB
- Disk: 40 GB
- Containers: postgres, postgREST, realtime, auth, storage, kong, studio, meta, analytics

---

### Option 3: Use Existing Infrastructure
**Pros:**
- No new infrastructure
- Leverage existing monitoring

**Cons:**
- No existing Postgres + PGVector setup
- Would need to add PGVector extension to any existing DB
- Archon expects Supabase-specific schema

**Feasibility:** Low. Archon has 1375-line migration specifically for Supabase.

---

## Recommendation

**For immediate deployment: Use Option 1 (Cloud Supabase)**

Reasons:
1. Faster time-to-value
2. Archon is beta software - might not work out
3. Can migrate to self-hosted later if needed
4. Free tier sufficient for initial testing

**Next steps if approved:**
1. Create Supabase project at https://supabase.com/dashboard
2. Run migration SQL (`/tmp/archon/migration/complete_setup.sql`)
3. Add credentials to Vault (`vault/archon/supabase`)
4. Complete Terraform deployment of Archon LXC (108)

---

## If Self-hosted Required

We need to:
1. Choose VMID for Supabase (suggest 107)
2. Add entry to `terraform/envs/prod/hosts.tf`
3. Create `107-supabase/` directory structure
4. Deploy Supabase via Docker Compose (separate from Archon)
5. Configure Archon to point to internal Supabase

**Timeline:** +2-3 days for Supabase setup/hardening
