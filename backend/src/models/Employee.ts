import mongoose, { Schema, Document } from 'mongoose';

export interface IEmployee extends Document {
  employeeId: string;
  name: string;
  designation: string;
  grade: string;
  category: string;
  gender: string;
  mobile: string;
  photoBase64: string | null;
  faceDescriptor: number[] | null; // 128-element face embedding vector
  createdAt: Date;
}

const EmployeeSchema = new Schema<IEmployee>(
  {
    employeeId: { type: String, required: true, unique: true, trim: true },
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

export const Employee = mongoose.model<IEmployee>('Employee', EmployeeSchema);
