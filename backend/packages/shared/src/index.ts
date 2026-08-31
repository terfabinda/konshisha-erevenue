export type UserRole = 'admin' | 'agent'

export type AdminScope = 'super_admin' | 'scoped_admin'

export interface Profile {
  id: string
  username: string
  display_name: string
  role: UserRole
  agency_id: string | null
  bound_device_fingerprint: string | null
  max_offline_days: number
  expiry_days: number | null
  login_expiry_at: string | null
  last_login_at: string | null
  is_active: boolean
  must_change_password: boolean
  created_at: string
  first_name?: string
  last_name?: string
  phone?: string
  tin?: string
  shop_name?: string
  location?: string
}

export interface Agency {
  id: string
  name: string
  code: string
  address: string | null
  phone: string | null
  email: string | null
  tin: string | null
  admin_name: string | null
  admin_phone: string | null
  receipt_prefix: number
  next_receipt_number: number
  custom_settings: Record<string, unknown> | null
  is_active: boolean
  onboarded_by: string | null
  onboarded_at: string | null
  created_at: string
}

export interface Receipt {
  id: string
  agency_id: string
  created_by: string
  payer_name: string
  payer_phone: string | null
  payer_tin: string | null
  payer_address: string | null
  category_id: string
  description: string
  amount: number
  discount: number | null
  penalty: number | null
  total_amount: number
  quantity: number
  status: 'active' | 'voided'
  voided_by: string | null
  voided_at: string | null
  notes: string | null
  device_fingerprint: string | null
  created_at: string
  updated_at: string | null
  receipt_ref: string | null
}

export interface PrintLog {
  id: string
  receipt_id: string
  receipt_ref: string | null
  printed_at: string
  copies: number
  print_mode: 'text' | 'image'
  printer_name: string | null
  printer_address: string | null
  printer_model: string | null
  success: boolean
  error_message: string | null
  printed_by: string
  agency_id: string | null
  is_reprint: boolean
}

export interface RevenueCategory {
  id: string
  name: string
  default_amount: number | null
  is_enabled: boolean
  sort_order: number
  created_at: string
}

export interface AgencyCategory {
  agency_id: string
  category_id: string
  enabled: boolean
  default_amount: number | null
}

export interface SecurityConfig {
  id: number
  max_offline_days: number
  login_expiry_days: number
  min_version_code: number
  force_sync: boolean
  security_alerts: string[]
  updated_at: string
}

export interface DashboardStats {
  today_revenue: number
  today_receipt_count: number
  recent_receipts: Receipt[]
  total_agencies?: number
  total_agents?: number
  total_revenue?: number
  total_receipts?: number
}

export interface RevenueStats {
  total_receipts: number
  total_revenue: number
  avg_amount: number
  top_categories: { category_id: string; revenue: number; count: number }[]
}

export interface PrintStats {
  total_prints: number
  success_count: number
  fail_count: number
  total_copies: number
  reprint_count: number
  success_rate: number
}
