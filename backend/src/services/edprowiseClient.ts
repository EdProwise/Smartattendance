// backend/src/services/edprowiseClient.ts

import axios from 'axios';


interface AttendanceData {
  schoolId: string | null;
  employeeId: string;
  timestamp: Date;
  type: 'checkin' | 'checkout';
}

interface SyncResponse {
  success: boolean;
  data?: any;
  error?: string;
}

const edprowiseClient = {
  async syncAttendance(attendanceData: AttendanceData): Promise<SyncResponse> {
    const baseUrl = process.env.EDPROWISE_ATTENDANCE_URL;
    if (!baseUrl) {
      const error = 'EDPROWISE_ATTENDANCE_URL is not set; attendance was not synced';
      console.error('[Edprowise]', error);
      return { success: false, error };
    }

    try {
      const payload = {
        schoolId: attendanceData.schoolId,
        employeeId: attendanceData.employeeId,
        date: attendanceData.timestamp,
        type: attendanceData.type,
      };

      console.log('[Edprowise] Syncing attendance:', payload);

      const response = await axios.post(
        `${baseUrl}/sync-attendance-from-smart-class`,
        payload,
        {
          headers: { 'Content-Type': 'application/json' },
          timeout: 10000,
        }
      );

      console.log('[Edprowise] Attendance synced successfully:', response.data);
      return { success: true, data: response.data };
    } catch (error: any) {
      console.error('[Edprowise] Error syncing attendance:', error.message);
      return { success: false, error: error.message };
    }
  }
};

export default edprowiseClient;