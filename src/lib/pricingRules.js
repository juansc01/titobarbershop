const FREE_CUSTOMER_PHONE = '665409016'

export const normalizePhone = (phone = '') => {
  const digits = String(phone).replace(/\D/g, '')

  // Spanish numbers may arrive with country code (34 + 9 digits)
  if (digits.length === 11 && digits.startsWith('34')) {
    return digits.slice(2)
  }

  // Also accept 0034 prefix if present
  if (digits.length === 13 && digits.startsWith('0034')) {
    return digits.slice(4)
  }

  return digits
}

export const isFreeCustomerPhone = (phone = '') => {
  return normalizePhone(phone) === FREE_CUSTOMER_PHONE
}

export const getAppointmentEffectivePrice = (appointment = {}) => {
  if (isFreeCustomerPhone(appointment?.customers?.phone || '')) return 0

  const rawPrice = appointment?.price ?? appointment?.services?.price ?? 0
  const parsed = Number(rawPrice)
  return Number.isFinite(parsed) ? parsed : 0
}

export { FREE_CUSTOMER_PHONE }

