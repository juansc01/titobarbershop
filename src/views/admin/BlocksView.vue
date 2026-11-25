<template>
  <div class="blocks-view">
    <div class="page-header">
      <div>
        <h1 class="page-title">Bloqueos</h1>
        <p class="page-desc">Vacaciones, descansos y ausencias</p>
      </div>
      <div class="header-actions">
        <button class="btn btn-secondary" @click="openVacationModal">+ Vacaciones</button>
        <button class="btn btn-primary" @click="openBlockModal">+ Bloqueo</button>
      </div>
    </div>

    <!-- Vacations -->
    <div class="section">
      <h2 class="section-title">Vacaciones</h2>
      <div v-if="vacations.length === 0" class="empty-card card">
        <p>No hay vacaciones programadas</p>
      </div>
      <div v-else class="blocks-list">
        <div v-for="v in vacations" :key="v.id" class="block-item card">
          <div class="block-info">
            <strong>{{ v.barbers?.name || 'Peluquero' }}</strong>
            <span>{{ formatDate(v.start_date) }} - {{ formatDate(v.end_date) }}</span>
            <span class="block-reason" v-if="v.reason">{{ v.reason }}</span>
          </div>
          <button class="btn btn-ghost btn-sm" style="color: var(--danger)" @click="removeVacation(v.id)">Eliminar</button>
        </div>
      </div>
    </div>

    <!-- Blocked times -->
    <div class="section">
      <h2 class="section-title">Bloqueos horarios</h2>
      <div v-if="groupedBlocks.length === 0" class="empty-card card">
        <p>No hay bloqueos activos</p>
      </div>
      <div v-else class="blocks-list">
        <div v-for="b in groupedBlocks" :key="b.id" class="block-item card">
          <div class="block-info">
            <strong>{{ b.barbers?.name || 'Peluquero' }}</strong>
            <span>{{ formatDateTime(b.start_datetime) }} - {{ formatDateTime(b.end_datetime) }}</span>
            <span class="block-reason" v-if="b.reason">{{ b.reason }}</span>
            <span class="block-reason" v-if="b.mergedCount > 1">{{ b.mergedCount }} slots/tramos agrupados</span>
            <span class="badge badge-warning">{{ blockTypeLabel(b.block_type) }}</span>

            <details class="slots-dropdown" v-if="getGroupSlots(b).length > 0">
              <summary>
                Gestionar slots ({{ getGroupSlots(b).length }})
              </summary>
              <div class="slots-dropdown-content">
                <div class="slot-row" v-for="slot in getGroupSlots(b)" :key="slot.startIso">
                  <span>{{ slot.label }}</span>
                  <button class="btn btn-ghost btn-sm" style="color: var(--danger);" @click.stop="removeSlotFromGroup(b, slot)">Quitar</button>
                </div>
              </div>
            </details>
          </div>
          <button class="btn btn-ghost btn-sm" style="color: var(--danger)" @click="removeBlockGroup(b)">Eliminar</button>
        </div>
      </div>
    </div>

    <!-- Vacation Modal -->
    <div v-if="showVacationModal" class="modal-overlay" @click.self="showVacationModal = false">
      <div class="modal-content">
        <h3 class="modal-title">Añadir vacaciones</h3>
        <div class="form-group">
          <label class="label">Peluquero</label>
          <select class="input" v-model="vacForm.barber_id">
            <option value="">Seleccionar...</option>
            <option v-for="b in barbers" :key="b.id" :value="b.id">{{ b.name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="label">Tipo de periodo</label>
          <div class="quick-options">
            <button class="btn btn-sm" :class="vacQuick === 'today' ? 'btn-primary' : 'btn-secondary'" @click="setVacQuick('today')">Hoy</button>
            <button class="btn btn-sm" :class="vacQuick === 'tomorrow' ? 'btn-primary' : 'btn-secondary'" @click="setVacQuick('tomorrow')">Mañana</button>
            <button class="btn btn-sm" :class="vacQuick === 'week' ? 'btn-primary' : 'btn-secondary'" @click="setVacQuick('week')">Esta semana</button>
            <button class="btn btn-sm" :class="vacQuick === 'custom' ? 'btn-primary' : 'btn-secondary'" @click="setVacQuick('custom')">Personalizado</button>
          </div>
        </div>
        <div v-if="vacQuick === 'custom'" class="form-row">
          <div class="form-group">
            <label class="label">Desde</label>
            <input class="input" type="date" v-model="vacForm.start_date" />
          </div>
          <div class="form-group">
            <label class="label">Hasta</label>
            <input class="input" type="date" v-model="vacForm.end_date" />
          </div>
        </div>
        <div v-else class="date-preview">
          📅 {{ formatDate(vacForm.start_date) }} → {{ formatDate(vacForm.end_date) }}
        </div>
        <div class="form-group">
          <label class="label">Motivo (opcional)</label>
          <input class="input" v-model="vacForm.reason" placeholder="Motivo" />
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" @click="showVacationModal = false">Cancelar</button>
          <button class="btn btn-primary" @click="saveVacation">Guardar</button>
        </div>
      </div>
    </div>

    <!-- Block Modal -->
    <div v-if="showBlockModal" class="modal-overlay" @click.self="showBlockModal = false">
      <div class="modal-content">
        <h3 class="modal-title">Añadir bloqueo horario</h3>
        <div class="form-group">
          <label class="label">Peluquero</label>
          <select class="input" v-model="blockForm.barber_id" @change="onBlockBarberChange">
            <option value="">Seleccionar...</option>
            <option v-for="b in barbers" :key="b.id" :value="b.id">{{ b.name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="label">Fecha</label>
          <input class="input" type="date" v-model="blockForm.date" @change="loadBlockSlots" />
        </div>
        <div class="form-group">
          <label class="label">Tipo</label>
          <select class="input" v-model="blockForm.block_type">
            <option value="absence">Ausencia</option>
          </select>
        </div>

        <!-- Slot selection -->
        <div v-if="blockForm.barber_id && blockForm.date" class="form-group">
          <label class="label">Selecciona los slots a bloquear</label>
          <div v-if="loadingSlots" class="skeleton" style="height: 40px; margin-top: 8px;"></div>
          <div v-else-if="daySlots.length === 0" class="empty-slots">
            <p>No hay slots disponibles para este día</p>
          </div>
          <div v-else class="slots-selector">
            <div
              v-for="slot in daySlots"
              :key="slot.time"
              class="slot-option"
              :class="{ selected: selectedBlockSlots.includes(slot.time), booked: slot.booked }"
              @click="toggleBlockSlot(slot)"
            >
              <span class="slot-time">{{ slot.time }}</span>
              <span v-if="slot.booked" class="slot-booked-badge">Reservado</span>
              <span v-else-if="selectedBlockSlots.includes(slot.time)" class="slot-check">✓</span>
            </div>
          </div>
        </div>

        <!-- Booked slot warning -->
        <div v-if="bookedWarnings.length > 0" class="booked-warnings">
          <div v-for="w in bookedWarnings" :key="w.time" class="warning-item">
            <span class="warning-icon">⚠️</span>
            <div class="warning-text">
              <strong>{{ w.time }}</strong> está reservado por <strong>{{ w.customerName }}</strong>
              <span v-if="w.phone"> ({{ w.phone }})</span>
              <p class="warning-note">Contacta con el cliente para avisarle del bloqueo.</p>
            </div>
          </div>
        </div>

        <div class="form-group">
          <label class="label">Motivo (opcional)</label>
          <input class="input" v-model="blockForm.reason" placeholder="Motivo" />
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" @click="showBlockModal = false">Cancelar</button>
          <button class="btn btn-primary" @click="saveBlock" :disabled="selectedBlockSlots.length === 0">
            {{ allDaySlotsSelected() ? 'Bloquear día completo' : `Bloquear ${selectedBlockSlots.length} slot${selectedBlockSlots.length !== 1 ? 's' : ''}` }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { scheduleService } from '../../services/scheduleService'
import { barbersService } from '../../services/barbersService'
import { appointmentsService } from '../../services/appointmentsService'
import { supabase } from '../../lib/supabase'
import { useToast } from '../../composables/useToast'
import { availabilityService } from '../../services/availabilityService'

export default {
  name: 'BlocksView',
  data() {
    return {
      barbers: [],
      vacations: [],
      blocks: [],
      showVacationModal: false,
      showBlockModal: false,
      vacQuick: 'today',
      vacForm: { barber_id: '', start_date: '', end_date: '', reason: '' },
      blockForm: { barber_id: '', date: '', block_type: 'absence', reason: '' },
      daySlots: [],
      selectedBlockSlots: [],
      bookedWarnings: [],
      loadingSlots: false
    }
  },
  async mounted() {
    await this.loadData()
  },
  computed: {
    groupedBlocks() {
      const source = [...this.blocks]
      if (source.length === 0) return []

      const byKey = new Map()
      for (const block of source) {
        const start = new Date(block.start_datetime)
        const end = new Date(block.end_datetime)
        if (isNaN(start.getTime()) || isNaN(end.getTime())) continue

        const dayKey = `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-${String(start.getDate()).padStart(2, '0')}`
        const groupKey = `${block.barber_id}|${block.block_type}|${block.reason || ''}|${dayKey}`

        const list = byKey.get(groupKey) || []
        list.push({ ...block, _start: start, _end: end })
        byKey.set(groupKey, list)
      }

      const grouped = []
      for (const list of byKey.values()) {
        list.sort((a, b) => a._start - b._start)
        let current = null

        for (const block of list) {
          if (!current) {
            current = {
              ...block,
              ids: [block.id],
              mergedCount: 1
            }
            continue
          }

          if (block._start.getTime() <= current._end.getTime()) {
            if (block._end.getTime() > current._end.getTime()) {
              current._end = block._end
              current.end_datetime = block.end_datetime
            }
            current.ids.push(block.id)
            current.mergedCount += 1
          } else {
            grouped.push(current)
            current = {
              ...block,
              ids: [block.id],
              mergedCount: 1
            }
          }
        }

        if (current) grouped.push(current)
      }

      return grouped.sort((a, b) => new Date(b.start_datetime) - new Date(a.start_datetime))
    }
  },
  methods: {
    async loadData() {
      try {
        const [barbers, vacations, blocks] = await Promise.all([
          barbersService.getAll(),
          scheduleService.getAllVacations(),
          scheduleService.getAllBlockedTimes()
        ])
        this.barbers = barbers
        this.vacations = vacations
        this.blocks = blocks
      } catch (e) { useToast().error('Error al cargar datos') }
    },
    openVacationModal() {
      this.vacQuick = 'today'
      this.setVacQuick('today')
      this.vacForm.barber_id = ''
      this.vacForm.reason = ''
      this.showVacationModal = true
    },
    openBlockModal() {
      this.blockForm = { barber_id: '', date: '', block_type: 'absence', reason: '' }
      this.daySlots = []
      this.selectedBlockSlots = []
      this.bookedWarnings = []
      this.showBlockModal = true
    },
    setVacQuick(type) {
      this.vacQuick = type
      const today = new Date()
      const toDateStr = (d) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`

      if (type === 'today') {
        this.vacForm.start_date = toDateStr(today)
        this.vacForm.end_date = toDateStr(today)
      } else if (type === 'tomorrow') {
        const tom = new Date(today)
        tom.setDate(tom.getDate() + 1)
        this.vacForm.start_date = toDateStr(tom)
        this.vacForm.end_date = toDateStr(tom)
      } else if (type === 'week') {
        const monday = new Date(today)
        monday.setDate(today.getDate() - (today.getDay() === 0 ? 6 : today.getDay() - 1))
        const friday = new Date(monday)
        friday.setDate(monday.getDate() + 4)
        this.vacForm.start_date = toDateStr(monday)
        this.vacForm.end_date = toDateStr(friday)
      }
    },
    onBlockBarberChange() {
      if (this.blockForm.date) this.loadBlockSlots()
    },
    async loadBlockSlots() {
      if (!this.blockForm.barber_id || !this.blockForm.date) return
      this.loadingSlots = true
      this.selectedBlockSlots = []
      this.bookedWarnings = []

      try {
        // Use effective schedule for the requested date (scheduled program or weekly fallback)
        const wh = await availabilityService.getEffectiveWorkingHours(this.blockForm.barber_id, this.blockForm.date)

        if (!wh || !wh.is_working) {
          this.daySlots = []
          this.loadingSlots = false
          return
        }

        // Get appointments for this day
        const dayStart = new Date(this.blockForm.date + 'T00:00:00')
        const dayEnd = new Date(this.blockForm.date + 'T23:59:59')

        const { data: apts } = await supabase
          .from('appointments')
          .select('*, customers(name, phone), services(name)')
          .eq('barber_id', this.blockForm.barber_id)
          .gte('start_time', dayStart.toISOString())
          .lte('start_time', dayEnd.toISOString())
          .neq('status', 'cancelled')

        // Generate standard 45-min slots
        const [startH, startM] = wh.start_time.split(':').map(Number)
        const [endH, endM] = wh.end_time.split(':').map(Number)
        const workStart = startH * 60 + startM
        const workEnd = endH * 60 + endM

        const segments = []
        if (wh.break_start_time && wh.break_end_time) {
          const [breakStartH, breakStartM] = wh.break_start_time.split(':').map(Number)
          const [breakEndH, breakEndM] = wh.break_end_time.split(':').map(Number)
          segments.push([workStart, breakStartH * 60 + breakStartM])
          segments.push([breakEndH * 60 + breakEndM, workEnd])
        } else {
          segments.push([workStart, workEnd])
        }

        const slots = []
        for (const [segmentStart, segmentEnd] of segments) {
          for (let min = segmentStart; min + 45 <= segmentEnd; min += 45) {
            const h = Math.floor(min / 60)
            const m = min % 60
            const timeStr = `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`

            const slotStart = new Date(this.blockForm.date + 'T00:00:00')
            slotStart.setHours(h, m, 0, 0)
            const slotEnd = new Date(slotStart)
            slotEnd.setMinutes(slotEnd.getMinutes() + 45)

            // Check if booked
            const bookedApt = (apts || []).find(apt => {
              const aptStart = new Date(apt.start_time)
              const aptEnd = new Date(apt.end_time)
              return slotStart < aptEnd && slotEnd > aptStart
            })

            slots.push({
              time: timeStr,
              datetime: slotStart.toISOString(),
              booked: !!bookedApt,
              customerName: bookedApt?.customers?.name || '',
              customerPhone: bookedApt?.customers?.phone || '',
              serviceName: bookedApt?.services?.name || ''
            })
          }
        }

        this.daySlots = slots
      } catch (e) {
        this.daySlots = []
      }
      this.loadingSlots = false
    },
    toggleBlockSlot(slot) {
      if (slot.booked) {
        // Show warning but still allow selecting
        const alreadyWarned = this.bookedWarnings.some(w => w.time === slot.time)
        if (!alreadyWarned) {
          this.bookedWarnings.push({
            time: slot.time,
            customerName: slot.customerName,
            phone: slot.customerPhone
          })
        }
      }
      const idx = this.selectedBlockSlots.indexOf(slot.time)
      if (idx >= 0) {
        this.selectedBlockSlots.splice(idx, 1)
        this.bookedWarnings = this.bookedWarnings.filter(w => w.time !== slot.time)
      } else {
        this.selectedBlockSlots.push(slot.time)
      }
    },
    allDaySlotsSelected() {
      return this.daySlots.length > 0 && this.selectedBlockSlots.length === this.daySlots.length
    },
    getSelectedSlotRanges() {
      const slotDuration = 45
      const selected = this.daySlots
        .filter(slot => this.selectedBlockSlots.includes(slot.time))
        .map(slot => ({
          ...slot,
          start: new Date(slot.datetime)
        }))
        .sort((a, b) => a.start - b.start)

      if (selected.length === 0) return []

      const ranges = []
      let currentStart = new Date(selected[0].start)
      let currentEnd = new Date(selected[0].start)
      currentEnd.setMinutes(currentEnd.getMinutes() + slotDuration)

      for (let i = 1; i < selected.length; i++) {
        const nextStart = new Date(selected[i].start)
        const expectedNext = new Date(currentEnd)

        if (nextStart.getTime() === expectedNext.getTime()) {
          currentEnd = new Date(nextStart)
          currentEnd.setMinutes(currentEnd.getMinutes() + slotDuration)
        } else {
          ranges.push({ start: new Date(currentStart), end: new Date(currentEnd) })
          currentStart = new Date(nextStart)
          currentEnd = new Date(nextStart)
          currentEnd.setMinutes(currentEnd.getMinutes() + slotDuration)
        }
      }

      ranges.push({ start: new Date(currentStart), end: new Date(currentEnd) })
      return ranges
    },
    async saveVacation() {
      if (!this.vacForm.barber_id || !this.vacForm.start_date || !this.vacForm.end_date) {
        useToast().error('Selecciona peluquero y fechas'); return
      }
      try {
        await scheduleService.createVacation(this.vacForm)
        useToast().success('Vacaciones añadidas')
        this.showVacationModal = false
        await this.loadData()
      } catch (e) { useToast().error('Error') }
    },
    async saveBlock() {
      if (!this.blockForm.barber_id || !this.blockForm.date || this.selectedBlockSlots.length === 0) {
        useToast().error('Selecciona al menos un slot'); return
      }
      try {
        const selectedRanges = this.getSelectedSlotRanges()

        if (this.allDaySlotsSelected()) {
          const sortedDaySlots = [...this.daySlots].sort((a, b) => a.time.localeCompare(b.time))
          const firstSlot = sortedDaySlots[0]
          const lastSlot = sortedDaySlots[sortedDaySlots.length - 1]

          const dayStart = new Date(firstSlot.datetime)
          const dayEnd = new Date(lastSlot.datetime)
          dayEnd.setMinutes(dayEnd.getMinutes() + 45)

          await scheduleService.createBlock({
            barber_id: this.blockForm.barber_id,
            block_type: this.blockForm.block_type,
            start_datetime: dayStart.toISOString(),
            end_datetime: dayEnd.toISOString(),
            reason: this.blockForm.reason || 'Día completo'
          })

          useToast().success('Día completo bloqueado')
        } else {
          // For partial selections, merge consecutive slots into a single range
          for (const range of selectedRanges) {
            const rangeLabel = `${range.start.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })} - ${range.end.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}`

            await scheduleService.createBlock({
              barber_id: this.blockForm.barber_id,
              block_type: this.blockForm.block_type,
              start_datetime: range.start.toISOString(),
              end_datetime: range.end.toISOString(),
              reason: this.blockForm.reason || `Bloqueo horario ${rangeLabel}`
            })
          }

          useToast().success(
            selectedRanges.length === 1
              ? 'Tramo horario bloqueado'
              : `${selectedRanges.length} tramo(s) bloqueado(s)`
          )
        }

        this.showBlockModal = false
        await this.loadData()
      } catch (e) { useToast().error('Error al crear bloqueo') }
    },
    async removeVacation(id) {
      if (!confirm('¿Eliminar vacaciones?')) return
      try { await scheduleService.deleteVacation(id); await this.loadData(); useToast().success('Eliminado') } catch (e) { useToast().error('Error') }
    },
    async removeBlockGroup(group) {
      const ids = Array.isArray(group.ids) ? group.ids : [group.id]
      const confirmMsg = ids.length > 1
        ? `¿Eliminar este tramo agrupado? Se borrarán ${ids.length} bloqueos.`
        : '¿Eliminar bloqueo?'
      if (!confirm(confirmMsg)) return

      try {
        for (const id of ids) {
          await scheduleService.deleteBlock(id)
        }
        await this.loadData()
        useToast().success('Eliminado')
      } catch (e) {
        useToast().error('Error')
      }
    },
    getGroupSlots(group) {
      const slotMinutes = 45
      const start = new Date(group.start_datetime)
      const end = new Date(group.end_datetime)
      if (isNaN(start.getTime()) || isNaN(end.getTime())) return []

      const slots = []
      const cursor = new Date(start)
      let safeGuard = 0

      while (cursor < end && safeGuard < 200) {
        const slotStart = new Date(cursor)
        const slotEnd = new Date(cursor)
        slotEnd.setMinutes(slotEnd.getMinutes() + slotMinutes)
        if (slotEnd > end) break

        slots.push({
          startIso: slotStart.toISOString(),
          label: `${slotStart.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })} - ${slotEnd.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}`
        })

        cursor.setMinutes(cursor.getMinutes() + slotMinutes)
        safeGuard += 1
      }

      return slots
    },
    async removeSlotFromGroup(group, slot) {
      const slotStart = new Date(slot.startIso)
      const slotEnd = new Date(slotStart)
      slotEnd.setMinutes(slotEnd.getMinutes() + 45)

      const groupStart = new Date(group.start_datetime)
      const groupEnd = new Date(group.end_datetime)
      const ids = Array.isArray(group.ids) ? group.ids : [group.id]

      if (!confirm(`¿Quitar el slot ${slot.label}? El tramo se dividirá automáticamente.`)) return

      try {
        for (const id of ids) {
          await scheduleService.deleteBlock(id)
        }

        if (slotStart > groupStart) {
          await scheduleService.createBlock({
            barber_id: group.barber_id,
            block_type: group.block_type,
            start_datetime: groupStart.toISOString(),
            end_datetime: slotStart.toISOString(),
            reason: group.reason || null
          })
        }

        if (slotEnd < groupEnd) {
          await scheduleService.createBlock({
            barber_id: group.barber_id,
            block_type: group.block_type,
            start_datetime: slotEnd.toISOString(),
            end_datetime: groupEnd.toISOString(),
            reason: group.reason || null
          })
        }

        await this.loadData()
        useToast().success('Slot eliminado y tramo actualizado')
      } catch (e) {
        useToast().error('No se pudo quitar el slot')
      }
    },
    async removeBlock(id) {
      if (!confirm('¿Eliminar bloqueo?')) return
      try { await scheduleService.deleteBlock(id); await this.loadData(); useToast().success('Eliminado') } catch (e) { useToast().error('Error') }
    },
    formatDate(d) {
      if (!d) return ''
      return new Date(d + 'T12:00:00').toLocaleDateString('es-ES', { day: 'numeric', month: 'short', year: 'numeric' })
    },
    formatDateTime(dt) { return new Date(dt).toLocaleString('es-ES', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) },
    blockTypeLabel(t) { const m = { block: 'Bloqueo', break: 'Descanso', absence: 'Ausencia' }; return m[t] || t }
  }
}
</script>

<style scoped>
.page-header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 24px; gap: 16px; flex-wrap: wrap; }
.page-title { font-size: 28px; font-weight: 800; margin-bottom: 4px; }
.page-desc { color: var(--text-secondary); font-size: 15px; }
.header-actions { display: flex; gap: 8px; }

.section { margin-bottom: 32px; }
.section-title { font-size: 18px; font-weight: 700; margin-bottom: 16px; }
.empty-card { text-align: center; padding: 24px; color: var(--text-secondary); font-size: 14px; }

.blocks-list { display: flex; flex-direction: column; gap: 8px; }
.block-item { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; gap: 16px; }
.block-info { display: flex; flex-direction: column; gap: 4px; font-size: 14px; }
.block-info strong { font-size: 14px; }
.block-info span { color: var(--text-secondary); font-size: 13px; }
.block-reason { font-style: italic; }

.slots-dropdown {
  margin-top: 6px;
  border: 1px solid var(--border-color);
  border-radius: var(--radius-sm);
  overflow: hidden;
}

.slots-dropdown summary {
  list-style: none;
  cursor: pointer;
  padding: 8px 10px;
  font-size: 12px;
  color: var(--text-secondary);
  background: var(--bg-tertiary);
}

.slots-dropdown summary::-webkit-details-marker { display: none; }

.slots-dropdown-content {
  border-top: 1px solid var(--border-color);
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.slot-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  font-size: 12px;
  color: var(--text-secondary);
  background: var(--bg-secondary);
  border-radius: 6px;
  padding: 6px 8px;
}

.form-group { margin-bottom: 16px; min-width: 0; overflow: hidden; }
.form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; }
.form-row .form-group { margin-bottom: 0; }
.modal-title { font-size: 18px; font-weight: 700; margin-bottom: 24px; }
.modal-actions { display: flex; gap: 12px; justify-content: flex-end; margin-top: 24px; flex-wrap: wrap; }

.quick-options { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 8px; }
.date-preview { padding: 12px 16px; background: var(--bg-tertiary); border-radius: var(--radius-md); font-size: 14px; color: var(--text-secondary); margin-bottom: 16px; }

.slots-selector { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 8px; }
.slot-option {
  padding: 10px 16px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-color);
  background: var(--bg-tertiary);
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  transition: var(--transition);
  display: flex;
  align-items: center;
  gap: 8px;
}
.slot-option:hover { border-color: var(--border-light); }
.slot-option.selected { border-color: var(--accent); background: var(--accent-light); }
.slot-option.booked { border-color: var(--warning); opacity: 0.8; }
.slot-option.booked.selected { border-color: var(--warning); background: rgba(245, 158, 11, 0.1); }
.slot-booked-badge { font-size: 10px; background: rgba(245, 158, 11, 0.2); color: var(--warning); padding: 2px 6px; border-radius: 4px; }
.slot-check { color: var(--accent); font-weight: 700; }
.empty-slots { padding: 16px; color: var(--text-tertiary); font-size: 13px; }

.booked-warnings { margin-top: 12px; display: flex; flex-direction: column; gap: 8px; }
.warning-item {
  display: flex;
  gap: 10px;
  padding: 12px 16px;
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.2);
  border-radius: var(--radius-md);
  font-size: 13px;
}
.warning-icon { font-size: 16px; flex-shrink: 0; }
.warning-text { flex: 1; }
.warning-text strong { color: var(--text-primary); }
.warning-note { color: var(--text-tertiary); font-size: 12px; margin-top: 4px; }

@media (max-width: 768px) {
  .header-actions { flex-wrap: wrap; }
  .header-actions .btn { flex: 1 1 auto; min-width: 0; font-size: 13px; }
  .modal-actions .btn { flex: 1 1 auto; min-width: 0; padding: 10px 12px; font-size: 13px; }
  .block-item { flex-direction: column; align-items: flex-start; }
  .form-row { grid-template-columns: 1fr; }
}
</style>

