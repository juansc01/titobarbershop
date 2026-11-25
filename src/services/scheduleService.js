import { supabase } from '../lib/supabase'

const DEFAULT_DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']

const toMinutes = (timeValue) => {
  if (!timeValue) return null
  const [h, m] = String(timeValue).split(':').map(Number)
  return h * 60 + m
}

const normalizeDate = (date) => (date instanceof Date ? date.toISOString().split('T')[0] : date)

const getDayOfWeek = (dateStr) => {
  const jsDate = new Date(dateStr + 'T12:00:00')
  let dayOfWeek = jsDate.getDay() - 1
  if (dayOfWeek < 0) dayOfWeek = 6
  return dayOfWeek
}

const isAppointmentInsideHours = (dayHours, appointmentStart, appointmentEnd) => {
  if (!dayHours || !dayHours.is_working) return false

  const workStart = toMinutes(dayHours.start_time)
  const workEnd = toMinutes(dayHours.end_time)
  const aptStart = appointmentStart.getHours() * 60 + appointmentStart.getMinutes()
  const aptEnd = appointmentEnd.getHours() * 60 + appointmentEnd.getMinutes()

  if (aptStart < workStart || aptEnd > workEnd) return false

  if (dayHours.break_start_time && dayHours.break_end_time) {
    const breakStart = toMinutes(dayHours.break_start_time)
    const breakEnd = toMinutes(dayHours.break_end_time)
    if (aptStart < breakEnd && aptEnd > breakStart) return false
  }

  return true
}

export const scheduleService = {
  DEFAULT_DAYS,

  createDefaultHours() {
    return Array.from({ length: 7 }, (_, i) => ({
      day_of_week: i,
      start_time: '09:00',
      end_time: '15:00',
      is_working: i < 5,
      has_break: false,
      break_start_time: '12:00',
      break_end_time: '13:00'
    }))
  },

  normalizeHours(data) {
    const defaults = this.createDefaultHours()
    if (!Array.isArray(data) || data.length === 0) return defaults

    return Array.from({ length: 7 }, (_, i) => {
      const existing = data.find(d => d.day_of_week === i)
      if (!existing) {
        return {
          ...defaults[i],
          is_working: false
        }
      }

      return {
        day_of_week: i,
        start_time: existing.start_time ? existing.start_time.slice(0, 5) : '09:00',
        end_time: existing.end_time ? existing.end_time.slice(0, 5) : '15:00',
        is_working: Boolean(existing.is_working),
        has_break: Boolean(existing.break_start_time && existing.break_end_time),
        break_start_time: existing.break_start_time ? existing.break_start_time.slice(0, 5) : '12:00',
        break_end_time: existing.break_end_time ? existing.break_end_time.slice(0, 5) : '13:00'
      }
    })
  },

  serializeHours(hours) {
    return (hours || []).map(h => ({
      day_of_week: h.day_of_week,
      start_time: h.start_time,
      end_time: h.end_time,
      is_working: h.is_working,
      break_start_time: h.has_break ? h.break_start_time : null,
      break_end_time: h.has_break ? h.break_end_time : null
    }))
  },

  validateHours(hours) {
    for (const h of (hours || [])) {
      if (!h.is_working) continue
      if (!h.start_time || !h.end_time) {
        return `Completa inicio y fin en ${DEFAULT_DAYS[h.day_of_week]}`
      }

      const start = toMinutes(h.start_time)
      const end = toMinutes(h.end_time)
      if (start >= end) {
        return `La hora de fin debe ser mayor en ${DEFAULT_DAYS[h.day_of_week]}`
      }

      if (h.has_break) {
        if (!h.break_start_time || !h.break_end_time) {
          return `Completa el turno partido en ${DEFAULT_DAYS[h.day_of_week]}`
        }
        const breakStart = toMinutes(h.break_start_time)
        const breakEnd = toMinutes(h.break_end_time)
        if (!(start < breakStart && breakStart < breakEnd && breakEnd < end)) {
          return `El descanso debe quedar dentro del horario en ${DEFAULT_DAYS[h.day_of_week]}`
        }
      }
    }
    return null
  },

  async getWorkingHours(barberId) {
    const { data, error } = await supabase
      .from('working_hours')
      .select('*')
      .eq('barber_id', barberId)
      .order('day_of_week')
    if (error) throw error
    return data
  },

  async updateWorkingHours(barberId, hours) {
    // Delete existing hours
    await supabase
      .from('working_hours')
      .delete()
      .eq('barber_id', barberId)

    // Insert new hours
    const rows = hours.map(h => ({ ...h, barber_id: barberId }))
    const { error } = await supabase
      .from('working_hours')
      .insert(rows)
    if (error) throw error
  },

  async getSchedulePrograms(barberId) {
    const { data, error } = await supabase
      .from('schedule_programs')
      .select('*, schedule_program_hours(*)')
      .eq('barber_id', barberId)
      .is('cancelled_at', null)
      .order('start_date', { ascending: false })
    if (error) throw error
    return data || []
  },

  async createScheduleProgram(payload) {
    const { data: program, error: programError } = await supabase
      .from('schedule_programs')
      .insert({
        barber_id: payload.barber_id,
        start_date: payload.start_date,
        end_date: payload.end_date || null,
        notes: payload.notes || null
      })
      .select()
      .single()
    if (programError) throw programError

    const rows = this.serializeHours(payload.hours).map(h => ({
      ...h,
      program_id: program.id
    }))

    const { error: hoursError } = await supabase
      .from('schedule_program_hours')
      .insert(rows)

    if (hoursError) {
      await supabase.from('schedule_programs').delete().eq('id', program.id)
      throw hoursError
    }

    return program
  },

  async updateScheduleProgram(programId, payload) {
    const { data: program, error: updateError } = await supabase
      .from('schedule_programs')
      .update({
        start_date: payload.start_date,
        end_date: payload.end_date || null,
        notes: payload.notes || null
      })
      .eq('id', programId)
      .select()
      .single()
    if (updateError) throw updateError

    const { error: deleteError } = await supabase
      .from('schedule_program_hours')
      .delete()
      .eq('program_id', programId)
    if (deleteError) throw deleteError

    const rows = this.serializeHours(payload.hours).map(h => ({
      ...h,
      program_id: programId
    }))
    const { error: insertError } = await supabase
      .from('schedule_program_hours')
      .insert(rows)
    if (insertError) throw insertError

    return program
  },

  async cancelScheduleProgram(programId) {
    const { error } = await supabase
      .from('schedule_programs')
      .delete()
      .eq('id', programId)
    if (error) throw error
  },

  async getConflictingPrograms(barberId, startDate, endDate, excludeProgramId = null) {
    let query = supabase
      .from('schedule_programs')
      .select('id, start_date, end_date')
      .eq('barber_id', barberId)
      .is('cancelled_at', null)
      .lte('start_date', endDate || '9999-12-31')
      .or(`end_date.gte.${startDate},end_date.is.null`)

    if (excludeProgramId) query = query.neq('id', excludeProgramId)

    const { data, error } = await query
    if (error) throw error
    return data || []
  },

  async getAppointmentsAffectedByProgram(barberId, startDate, endDate, hours) {
    const rangeStart = new Date(startDate + 'T00:00:00')
    const rangeEnd = endDate
      ? new Date(endDate + 'T23:59:59')
      : null

    let query = supabase
      .from('appointments')
      .select('id, start_time, end_time, status, customers(name, phone), services(name)')
      .eq('barber_id', barberId)
      .in('status', ['confirmed', 'completed'])
      .gte('start_time', rangeStart.toISOString())
      .order('start_time', { ascending: true })

    if (rangeEnd) {
      query = query.lte('start_time', rangeEnd.toISOString())
    }

    const { data, error } = await query
    if (error) throw error

    const hoursByDay = new Map((hours || []).map(h => [h.day_of_week, h]))

    return (data || []).filter(apt => {
      const aptStart = new Date(apt.start_time)
      const aptEnd = new Date(apt.end_time)
      const aptDate = normalizeDate(aptStart)

      if (aptDate < startDate) return false
      if (endDate && aptDate > endDate) return false

      const dayOfWeek = getDayOfWeek(aptDate)
      const dayHours = hoursByDay.get(dayOfWeek)

      return !isAppointmentInsideHours(dayHours, aptStart, aptEnd)
    })
  },

  async getVacations(barberId) {
    const { data, error } = await supabase
      .from('vacations')
      .select('*')
      .eq('barber_id', barberId)
      .order('start_date', { ascending: false })
    if (error) throw error
    return data
  },

  async getAllVacations() {
    const { data, error } = await supabase
      .from('vacations')
      .select('*, barbers(name)')
      .order('start_date', { ascending: false })
    if (error) throw error
    return data
  },

  async createVacation(vacation) {
    const { data, error } = await supabase
      .from('vacations')
      .insert(vacation)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async deleteVacation(id) {
    const { error } = await supabase
      .from('vacations')
      .delete()
      .eq('id', id)
    if (error) throw error
  },

  async getBlockedTimes(barberId) {
    const { data, error } = await supabase
      .from('blocked_times')
      .select('*')
      .eq('barber_id', barberId)
      .order('start_datetime', { ascending: false })
    if (error) throw error
    return data
  },

  async getAllBlockedTimes() {
    const { data, error } = await supabase
      .from('blocked_times')
      .select('*, barbers(name)')
      .order('start_datetime', { ascending: false })
    if (error) throw error
    return data
  },

  async createBlock(block) {
    const { data, error } = await supabase
      .from('blocked_times')
      .insert(block)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async deleteBlock(id) {
    const { error } = await supabase
      .from('blocked_times')
      .delete()
      .eq('id', id)
    if (error) throw error
  },

  async isBarberAvailable(barberId, date) {
    const dateStr = normalizeDate(date)

    // Check vacations
    const { data: vacations } = await supabase
      .from('vacations')
      .select('id')
      .eq('barber_id', barberId)
      .lte('start_date', dateStr)
      .gte('end_date', dateStr)
      .limit(1)

    if (vacations && vacations.length > 0) return false

    // Check effective working hours (scheduled program for this date, or fallback weekly hours)
    let dayOfWeek = getDayOfWeek(dateStr)

    const { data: activeProgram } = await supabase
      .from('schedule_programs')
      .select('id')
      .eq('barber_id', barberId)
      .is('cancelled_at', null)
      .lte('start_date', dateStr)
      .or(`end_date.gte.${dateStr},end_date.is.null`)
      .order('start_date', { ascending: false })
      .limit(1)

    let hours = null
    if (activeProgram && activeProgram.length > 0) {
      const { data: programHours } = await supabase
        .from('schedule_program_hours')
        .select('*')
        .eq('program_id', activeProgram[0].id)
        .eq('day_of_week', dayOfWeek)
        .single()
      hours = programHours
    }

    if (!hours) {
      const { data: weeklyHours } = await supabase
        .from('working_hours')
        .select('*')
        .eq('barber_id', barberId)
        .eq('day_of_week', dayOfWeek)
        .single()
      hours = weeklyHours
    }

    if (!hours || !hours.is_working) return false
    return true
  }
}

