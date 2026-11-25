<template>
  <div class="schedule-view">
    <div class="page-header">
      <div>
        <h1 class="page-title">Horarios</h1>
        <p class="page-desc">Configura el horario de trabajo de cada peluquero</p>
      </div>
    </div>

    <div class="form-group" style="max-width: 300px; margin-bottom: 24px;">
      <label class="label">Peluquero</label>
      <div class="select-field select-barber">
        <select class="input" v-model="selectedBarberId" @change="loadHours">
          <option value="">Seleccionar peluquero...</option>
          <option v-for="b in barbers" :key="b.id" :value="b.id">{{ b.name }}</option>
        </select>
      </div>
    </div>

    <div v-if="selectedBarberId && !loading" class="schedule-wrapper">
      <WeeklyHoursEditor v-model="hours" :days="days" />
      <button class="btn btn-primary" @click="saveHours" style="margin-top: 16px;">Guardar horarios</button>
    </div>

    <div v-if="loading" class="skeleton-list">
      <div class="skeleton" style="height: 50px" v-for="i in 7" :key="i"></div>
    </div>
  </div>
</template>

<script>
import { barbersService } from '../../services/barbersService'
import { scheduleService } from '../../services/scheduleService'
import { useToast } from '../../composables/useToast'
import WeeklyHoursEditor from '../../components/admin/WeeklyHoursEditor.vue'

export default {
  name: 'ScheduleView',
  components: { WeeklyHoursEditor },
  data() {
    return {
      loading: false,
      barbers: [],
      selectedBarberId: '',
      days: scheduleService.DEFAULT_DAYS,
      hours: scheduleService.createDefaultHours()
    }
  },
  async mounted() {
    try { this.barbers = await barbersService.getAll() } catch (e) {}
  },
  methods: {
    async loadHours() {
      if (!this.selectedBarberId) return
      this.loading = true
      try {
        const data = await scheduleService.getWorkingHours(this.selectedBarberId)
        this.hours = scheduleService.normalizeHours(data)
      } catch (e) { useToast().error('Error al cargar horarios') }
      this.loading = false
    },
    async saveHours() {
      try {
        const validationError = scheduleService.validateHours(this.hours)
        if (validationError) {
          useToast().error(validationError)
          return
        }
        const hoursData = scheduleService.serializeHours(this.hours)
        await scheduleService.updateWorkingHours(this.selectedBarberId, hoursData)
        useToast().success('Horarios guardados')
      } catch (e) { useToast().error('Error al guardar') }
    }
  }
}
</script>

<style scoped>
.page-header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 24px; }
.page-title { font-size: 28px; font-weight: 800; margin-bottom: 4px; }
.page-desc { color: var(--text-secondary); font-size: 15px; }
.skeleton-list { display: flex; flex-direction: column; gap: 8px; }

.schedule-wrapper { max-width: 500px; }
.form-group { margin-bottom: 0; }
</style>


