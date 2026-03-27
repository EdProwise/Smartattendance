import mongoose, { Schema, Document } from 'mongoose';

export interface IEmployee extends Document {
  schoolId: string | null;  // null = legacy / super-admin-only
  employeeId: string;
  name: string;
  designation: string;
  grade: string;
  category: string;
  gender: string;
  mobile: string;
  photoBase64: string | null;
  faceDescriptor: number[] | null;
  createdAt: Date;
}

const EmployeeSchema = new Schema<IEmployee>(
  {
    schoolId: { type: String, default: null, index: true },
    employeeId: { type: String, required: true, trim: true },
    name: { type: String, required: true, trim: true },
    designation: { type: String, default: '', trim: true },
    grade: { type: String, default: '', trim: true },
    category: { type: String, default: '', trim: true },
    gender: { type: String, default: '', trim: true },
    mobile: { type: String, default: '', trim: true },
    photoBase64: { type: String, default: null },
    faceDescriptor: { type: [Number], default: null },
  },
  { timestamps: true }
);

// Unique employeeId per school (null schoolId still needs unique employeeId among nulls)
EmployeeSchema.index({ employeeId: 1, schoolId: 1 }, { unique: true });

export const Employee = mongoose.model<IEmployee>('Employee', EmployeeSchema);
