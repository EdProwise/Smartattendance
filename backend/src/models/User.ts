import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
  loginId: string;
  email: string;
  passwordHash: string;
  salt?: string;
  role: string;       // 'admin' | 'school_admin' | 'user'
  schoolId?: string; 
  createdAt: Date;
  resetToken?: string;
  resetTokenExpiry?: Date;
  profilePinHash?: string;
}

const UserSchema = new Schema<IUser>(
  {
    loginId: { type: String, required: true, unique: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    salt: { type: String, default: null }, 
    role: { type: String, default: 'user' },
    schoolId: { type: String, default: null },
    resetToken: { type: String },
    resetTokenExpiry: { type: Date },
    profilePinHash: { type: String, default: null },
  },
  { timestamps: true }
);

export const User = mongoose.model<IUser>('User', UserSchema);
